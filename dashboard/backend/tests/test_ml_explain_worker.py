"""The Groq explanation (checks, cache, budget, template when it fails) and the worker
(one round with a fake Supabase and a fake Groq: statuses, codes, no service_role)."""
import json
from datetime import datetime, timedelta, timezone
from pathlib import Path

import httpx
import pytest

from ml import explain as E
from ml import models as M
from ml import worker as W
from ml.factors import CODES

FIX = json.loads((Path(__file__).parent / "ml_fixtures" / "sim_history.json").read_text())
GOOD = {"ar": {"text": "الشجر في المنطقة ب عطشان. التربة ناشفة.", "action": "شوف خط السقي واسقي."},
        "fr": {"text": "Les arbres de la Zone B ont soif. Le sol est sec.", "action": "Vérifiez l'irrigation et arrosez."}}
FACTS = E.build_facts("stress", "water_deficit", "likely",
                      [{"code": "soil_water", "level": "low"}, {"code": "air_dryness", "level": "high"}],
                      "المنطقة ب", "Zone B", {"soil_moisture_pct": 12.4, "air_temp_c": 34}, "14:15")


def groq(responses: list):
    """A fake Groq: answers in order; counts the calls."""
    calls = []

    def handler(request: httpx.Request):
        calls.append(json.loads(request.content))
        status, body = responses[min(len(calls), len(responses)) - 1]
        if isinstance(body, dict) and "choices" not in body:
            body = {"choices": [{"message": {"content": json.dumps(body, ensure_ascii=False)}}]}
        return httpx.Response(status, json=body) if not isinstance(body, str) else httpx.Response(status, text=body)

    return httpx.Client(transport=httpx.MockTransport(handler)), calls


def test_facts_are_words_not_feature_names():
    text = json.dumps(FACTS, ensure_ascii=False)
    assert "rew_predawn" not in text and "vpd" not in text
    assert FACTS["factors"][0] == {"ar": "ماء قليل في التربة", "fr": "peu d'eau dans le sol"}
    assert FACTS["state_ar"] == "نقص في الماء" and FACTS["safe_action_fr"].startswith("Vérifiez")
    assert FACTS["readings"] == {"soil_moisture_pct": 12, "air_temp_c": 34, "time": "14:15"}


@pytest.mark.parametrize("bad, why", [
    ({"ar": GOOD["ar"]}, "shape"),
    ({**GOOD, "ar": {"text": "الحرارة 34 درجة.", "action": "اسقي."}}, "number"),
    ({**GOOD, "fr": {"text": "Il fait ٣٤ degrés.", "action": "Arrosez."}}, "number"),
    ({**GOOD, "ar": {"text": "الشجر عطشان، water.", "action": "اسقي."}}, "latin_in_arabic"),
    ({**GOOD, "ar": {"text": "الشجر مريض.", "action": "رش مبيد على الشجر."}}, "banned_word"),
    ({**GOOD, "fr": {"text": "Les arbres sont malades.", "action": "Mettez un fongicide."}}, "banned_word"),
    ({**GOOD, "fr": {"text": "x" * 700, "action": "ok"}}, "length"),
    ({**GOOD, "fr": {"text": "", "action": "ok"}}, "length"),
])
def test_wrong_answers_are_refused(bad, why):
    assert E.check_answer(bad, FACTS) == why


def test_a_good_answer_passes_and_derja_word_barsha_is_not_banned():
    assert E.check_answer(GOOD, FACTS) is None
    for word, banned in [("للتربة", False), ("التربة", False), ("لترات", True), ("باللتر", True), ("والمبيدات", True)]:
        assert E._banned(word) is banned, word
    ok = {**GOOD, "ar": {"text": "التربة ناشفة برشا في المنطقة ب.", "action": "اسقي."}}
    assert E.check_answer(ok, FACTS) is None


def test_parse_answer_reads_fences_and_think():
    raw = "<think>hmm</think>```json\n" + json.dumps(GOOD, ensure_ascii=False) + "\n```"
    assert E.parse_answer(raw) == GOOD
    assert E.parse_answer("not json") is None


def test_groq_ok_then_cached_and_reused_from_the_last_prediction():
    client, calls = groq([(200, GOOD)])
    ex = E.Explainer("gsk_test", "qwen/qwen3.8-27b", client=client)
    key = E.explanation_key("stress", "water_deficit", "likely", [{"code": "soil_water", "level": "low"}], "Zone B")
    e = ex.explain(FACTS, key)
    assert e.source == "groq:qwen/qwen3.8-27b" and e.texts["ar"]["text"].startswith("الشجر")
    assert calls[0]["model"] == "qwen/qwen3.8-27b" and calls[0]["response_format"] == {"type": "json_object"}
    assert "FACTS" in calls[0]["messages"][1]["content"] and "Derja" in calls[0]["messages"][0]["content"]
    assert ex.explain(FACTS, key).texts == e.texts and len(calls) == 1                 # same key: no new call
    fresh = E.Explainer("gsk_test", "qwen/qwen3.8-27b", client=client)
    prev = {"explanation_key": key, "explanation_ar": "نص قديم", "action_ar": "x", "explanation_fr": "vieux",
            "action_fr": "y", "explanation_source": "groq:qwen/qwen3.8-27b"}
    assert fresh.explain(FACTS, key, prev).texts["ar"]["text"] == "نص قديم" and len(calls) == 1


def test_the_key_changes_with_the_zone_and_the_reasons():
    f = [{"code": "soil_water", "level": "low"}]
    k1 = E.explanation_key("stress", "water_deficit", "likely", f, "Zone B")
    assert k1 != E.explanation_key("stress", "water_deficit", "likely", f, "Zone C")
    assert k1 != E.explanation_key("stress", "water_deficit", "unsure", f, "Zone B")
    assert k1 != E.explanation_key("stress", "water_deficit", "likely", [{"code": "air_heat", "level": "high"}], "Zone B")


@pytest.mark.parametrize("response", [
    (429, {"error": {"message": "rate limit"}}), (503, {"error": "busy"}), (200, "not json at all"),
    (200, {"choices": [{"message": {"content": "{\"ar\": 1}"}}]}),
    (200, {**GOOD, "ar": {"text": "الحرارة 34.", "action": "اسقي."}}),
])
def test_groq_failures_give_the_template(response):
    client, calls = groq([response])
    ex = E.Explainer("gsk_test", "qwen/qwen3.8-27b", client=client)
    e = ex.explain(FACTS, "k")
    assert e.texts is None and e.source == "template" and len(calls) == 1


def test_no_key_or_budget_used_up_gives_the_template_without_calling():
    client, calls = groq([(200, GOOD)])
    assert E.Explainer("", "qwen/qwen3.8-27b", client=client).explain(FACTS, "k").source == "template"
    ex = E.Explainer("gsk_test", "qwen/qwen3.8-27b", per_minute=2, client=client)
    sources = [ex.explain(FACTS, f"k{i}").source for i in range(4)]
    assert sources == ["groq:qwen/qwen3.8-27b"] * 2 + ["template"] * 2 and len(calls) == 2
    client2, calls2 = groq([(429, {"error": "x"}), (200, GOOD)])
    ex2 = E.Explainer("gsk_test", "qwen/qwen3.8-27b", client=client2)
    ex2.explain(FACTS, "a")
    assert ex2.explain(FACTS, "b").source == "template" and len(calls2) == 1       # paused 60 s after a 429


def test_zone_names_use_arabic_letters():
    assert W.zone_names("B", "") == ("المنطقة ب", "Zone B")
    assert W.zone_names("D", None) == ("المنطقة د", "Zone D")
    assert W.zone_names("A", "الزيتونة") == ("الزيتونة", "الزيتونة")


class FakeDB:
    """ml_worker_jobs / ml_worker_history / ml_worker_save of migration 019, in memory."""

    def __init__(self, scenario: str, until: datetime, levels: dict | None = None, short: str | None = None):
        self.saved, self.until = [], until
        self.hist = {}
        for dev, pts in FIX[scenario].items():
            pts = [p for p in pts if p[0] <= until.timestamp()]
            if dev == short:
                pts = pts[-8:]
            self.hist[dev] = pts
        ctx = {"NODE-01": ("sandy_loam", .25, .11, .44, "mid"), "NODE-02": ("sandy_loam", .25, .11, .44, "mid"),
               "NODE-03": ("loamy_sand", .174, .071, .43, "high"), "NODE-04": ("sand", .12, .05, .43, "low")}
        self.jobs_list = []
        for dev, (soil, fc, wp, sat, pos) in ctx.items():
            last = self.hist[dev][-1]
            self.jobs_list.append({
                "node_id": dev, "device_code": dev, "zone_id": "z" + dev[-1], "zone_letter": "ABCD"[int(dev[-1]) - 1],
                "zone_name": "", "orchard_id": "orch", "farmer_id": "f",
                "measured_at": datetime.fromtimestamp(last[0], timezone.utc).isoformat(),
                "level": (levels or {}).get(dev, "ok"), "faults": [],
                "latest": {"soil_moisture_pct": last[1], "soil_temp_c": last[2], "air_temp_c": last[3],
                           "humidity_pct": last[4], "light_adc": last[5], "piezo_rms": last[6], "piezo_events_h": last[7]},
                "context": dict(soil_type=soil, theta_fc=fc, theta_wp=wp, theta_sat=sat, node_position=pos,
                                irrigation_system="drip", irrigation_water_ec_dsm=None, ground_cover_frac=.45,
                                cover_crop=False, root_depth_m=.6, bloom_start="01-20", latitude=34.74, elevation_m=20,
                                defaults=[]),
                "previous": {}})

    def jobs(self, limit=50):
        return {"settings": {"ml_enabled": True, "ml_explain_enabled": True, "ml_groq_model": "qwen/qwen3.8-27b",
                             "ml_likely_min": 0.6}, "jobs": self.jobs_list}

    def history(self, orchard_id, since):
        return {"nodes": self.hist}

    def save(self, predictions):
        json.dumps(predictions)                         # what is sent must be plain JSON
        self.saved.append(predictions)
        return {"saved": len(predictions)}


@pytest.fixture(scope="module")
def models():
    return M.load()


def _check_prediction(p):
    assert p["model"] in ("frost", "stress") and p["status"] in ("ok", "not_enough_data", "sensor_problem")
    if p["status"] == "ok":
        assert p["state"] in (["frost_risk", "no_frost"] if p["model"] == "frost"
                              else ["none", "water_deficit", "waterlogging", "heat", "frost", "rootzone"])
        assert 0 <= p["confidence"] <= 1 and p["certainty"] in ("likely", "unsure")
        assert p["factors"] and all(f["code"] in CODES for f in p["factors"])
        assert abs(sum(f["share"] for f in p["factors"]) - 1) < 0.01
    else:
        assert p["state"] is None


def test_worker_summer_round(models):
    db = FakeDB("summer", datetime(2026, 6, 16, 13, 0, tzinfo=timezone.utc), levels={"NODE-04": "sensor"}, short="NODE-01")
    client, calls = groq([(200, GOOD)])
    worker = W.Worker(db, models, E.Explainer("gsk_test", "x", client=client))
    r = worker.run_once()
    preds = {(p["node_id"], p["model"]): p for p in db.saved[0]}
    assert r["jobs"] == 4 and len(preds) == 8
    for p in preds.values():
        _check_prediction(p)
    assert preds[("NODE-04", "stress")]["status"] == "sensor_problem" == preds[("NODE-04", "frost")]["status"]
    assert preds[("NODE-01", "stress")]["status"] == "not_enough_data"
    assert preds[("NODE-02", "stress")]["state"] == "water_deficit"            # the leaking irrigation line
    assert preds[("NODE-03", "stress")]["state"] == "heat"                     # the hot zone
    assert preds[("NODE-02", "frost")]["state"] == "no_frost"
    assert preds[("NODE-02", "stress")]["explanation"] == GOOD and preds[("NODE-02", "stress")]["explanation_source"] == "groq:qwen/qwen3.8-27b"
    assert preds[("NODE-02", "stress")]["readings"]["soil_moisture_pct"] is not None
    first = len(calls)
    # the next round with the same predictions: the texts come back from "previous", no new Groq call
    for j in db.jobs_list:
        j["previous"] = {p["model"]: {"explanation_key": p.get("explanation_key"), "explanation_ar": "ن",
                                      "action_ar": "ن", "explanation_fr": "t", "action_fr": "a",
                                      "explanation_source": "groq:qwen/qwen3.8-27b"}
                         for p in db.saved[0] if p["node_id"] == j["node_id"]}
    worker.run_once()
    assert len(calls) == first


def test_worker_frost_night(models):
    db = FakeDB("frost", datetime(2027, 2, 18, 19, 0, tzinfo=timezone.utc))         # 20:00 in Sfax
    worker = W.Worker(db, models, None)
    worker.run_once()
    preds = {(p["node_id"], p["model"]): p for p in db.saved[0]}
    assert preds[("NODE-04", "frost")]["state"] == "frost_risk"                 # the low spot freezes first
    assert preds[("NODE-03", "frost")]["state"] == "no_frost"                   # the high zone does not
    assert preds[("NODE-04", "frost")]["threshold"] == pytest.approx(0.664, abs=0.001)
    assert preds[("NODE-04", "frost")]["explanation"] is None and preds[("NODE-04", "frost")]["explanation_source"] == "template"
    codes = [f["code"] for f in preds[("NODE-04", "frost")]["factors"]]
    assert set(codes) <= set(CODES) and len(codes) >= 2
    assert preds[("NODE-01", "stress")]["state"] == "none"
    assert not any(k.startswith("_") for p in db.saved[0] for k in p)          # nothing internal is sent


def test_problems_get_the_groq_budget_first(models):
    db = FakeDB("frost", datetime(2027, 2, 18, 21, 30, tzinfo=timezone.utc))
    client, calls = groq([(200, GOOD)])
    worker = W.Worker(db, models, E.Explainer("gsk_test", "x", per_minute=1, client=client))
    worker.run_once()
    with_text = [p for p in db.saved[0] if p["explanation"]]
    assert len(calls) == 1 and len(with_text) == 1 and with_text[0]["state"] == "frost_risk"


def test_worker_needs_its_own_key_never_the_service_role(monkeypatch, tmp_path):
    env = {"SUPABASE_URL": "https://x.supabase.co", "SUPABASE_ANON_KEY": "public", "ML_WORKER_KEY": "",
           "SUPABASE_SERVICE_ROLE_KEY": "secret"}
    with pytest.raises(SystemExit, match="ML_WORKER_KEY"):
        W.build(env)
    with pytest.raises(SystemExit, match="lml_"):
        W.build({**env, "ML_WORKER_KEY": "secret"})
    sent = []
    client = httpx.Client(transport=httpx.MockTransport(lambda r: sent.append(r) or httpx.Response(200, json={"jobs": []})))
    db = W.Supabase("https://x.supabase.co", "public", "lml_" + "a" * 64, client=client)
    db.jobs()
    assert sent[0].url.path == "/rest/v1/rpc/ml_worker_jobs"
    assert sent[0].headers["apikey"] == "public" and sent[0].headers["authorization"] == "Bearer public"
    assert json.loads(sent[0].content)["p_key"] == "lml_" + "a" * 64
