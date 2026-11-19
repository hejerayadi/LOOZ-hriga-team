"""LIVE test of the VOICE ASSISTANT "لوز" (migration 017 + Edge Function
"voice-token" + the REAL Gemini Live), against the REAL Supabase.

    pytest tests_live/test_live_voice.py -v -s

What it does (like the app, but the question is TYPED: no microphone here):
  1. Not logged in -> 401; a Free farmer (22 123 457) -> not_paid.
  2. 22 777 001 says "yes" to the voice message (voice_set_consent, like the
     button "موافق"), asks voice-token for Google's token, opens the
     connection to Gemini Live with it, asks "شنوّة حال السانية؟".
  3. Gemini asks for get_my_orchard: answered like the app (his zones and
     the last reading of each sensor box, read with HIS login).
  4. The answer of "لوز": its text (printed) and its voice (saved as a WAV
     file to listen to: printed path, never in git).
  5. voice_end: the time is counted by the database (no words saved).
  6. The same in French ("Comment va mon verger ?").
Each conversation uses at least 20 seconds of his 5 minutes of the day.
Needs the app's demo login on (to log in as the app users).
"""
import base64
import json
import os
import socket
import ssl
import tempfile
import time
import wave
from datetime import datetime
from urllib.parse import urlencode

import pytest
from websockets.sync.client import connect

from tests_live.test_live_iot import ENV, HTTP, PUBLIC_KEY, URL
from tests_live.test_live_phase_b import app_get, app_login, app_rpc

FARMER = "+21622777001"      # paid, demo, Sfax (IoT boxes)
FREE_FARMER = "+21622123457"  # Free
FUNCTION = f"{URL}/functions/v1/voice-token"
GOOGLE = "generativelanguage.googleapis.com"
PATH = "/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContentConstrained"
IPV4_ONLY = str(ENV.get("SUPABASE_IPV4_ONLY", "")).lower() == "true"
# The letters of the zones, like lib/core/zone_letters.dart (ARB "zoneLetters").
ABJAD = "أ ب ج د ه و ز ح ط ي ك ل م ن س ع ف ص ق ر".split()
LATIN = "A B C D E F G H I J K L M N O P Q R S T".split()


@pytest.fixture(scope="module")
def farmer():
    return app_login(FARMER)


@pytest.fixture(scope="module")
def free_farmer():
    return app_login(FREE_FARMER)


def voice_token(token: str | None, lang: str = "ar"):
    h = {"apikey": PUBLIC_KEY, "Content-Type": "application/json"}
    if token:
        h["Authorization"] = f"Bearer {token}"
    r = HTTP.post(FUNCTION, headers=h, json={"lang": lang}, timeout=40)
    if r.status_code == 404:
        pytest.fail('the Edge Function "voice-token" is not deployed')
    return r.status_code, r.json()


def my_orchard(token: str) -> dict:
    """get_my_orchard, exactly like lib/data/voice_tools.dart."""
    orchard = app_get(token, "orchards?select=id,status")
    if not orchard or orchard[0]["status"] != "complete":
        return {"zones": [], "note": "orchard_not_drawn_yet"}
    oid = orchard[0]["id"]
    zones = app_get(token, f"zones?select=id,letter,name,zone_type,tree_count,cultivar"
                           f"&orchard_id=eq.{oid}&archived_at=is.null&order=letter.asc")
    boxes = app_get(token, "iot_node_status?select=zone_id,status,measured_at,soil_moisture_pct,soil_temp_c,"
                           f"air_temp_c,humidity_pct,battery_pct,level,reasons,cause&orchard_id=eq.{oid}")
    by_zone = {b["zone_id"]: b for b in boxes}
    now = time.time()
    out = []
    for z in zones:
        i = LATIN.index(z["letter"]) if z.get("letter") in LATIN else None
        b = by_zone.get(z["id"])
        item = {"zone_ar": f"المنطقة {ABJAD[i] if i is not None else z.get('letter')}",
                "zone_fr": f"Zone {z.get('letter')}"}
        for key, name in (("name", "name"), ("zone_type", "type"), ("tree_count", "trees"), ("cultivar", "cultivar")):
            if z.get(key) is not None:
                item[name] = z[key]
        item["box"] = b["status"] if b else "none"
        if b:
            if b.get("measured_at"):
                t = datetime.fromisoformat(b["measured_at"].replace("Z", "+00:00")).timestamp()
                item["minutes_since_reading"] = int((now - t) // 60)
            for key in ("soil_moisture_pct", "soil_temp_c", "air_temp_c", "humidity_pct", "battery_pct"):
                if b.get(key) is not None:
                    item[key] = round(b[key], 1)
            if b.get("level"):
                item["level"] = b["level"]
            if b.get("reasons"):
                item["reasons"] = b["reasons"]
            if b.get("cause"):
                item["cause"] = b["cause"]
        out.append(item)
    return {"now": time.strftime("%Y-%m-%dT%H:%M:%S"), "zones": out}


def google_socket():
    """Google's WebSocket (IPv4 when SUPABASE_IPV4_ONLY: this laptop's IPv6 is broken)."""
    family = socket.AF_INET if IPV4_ONLY else 0
    info = socket.getaddrinfo(GOOGLE, 443, family, socket.SOCK_STREAM)[0]
    sock = socket.socket(info[0], info[1], info[2])
    sock.settimeout(20)
    sock.connect(info[4])
    return sock


def converse(ticket: dict, question: str, token: str) -> dict:
    """One question to "لوز" -> {text, audio_seconds, tools, tokens, wav}."""
    uri = f"wss://{GOOGLE}{PATH}?{urlencode({'access_token': ticket['token']})}"
    sock = google_socket()
    result = {"text": "", "audio": bytearray(), "tools": [], "tokens": (0, 0), "zones": None}
    with connect(uri, sock=sock, server_hostname=GOOGLE, ssl=ssl.create_default_context(),
                 open_timeout=20, max_size=None) as ws:
        ws.send(json.dumps({"setup": {"model": f"models/{ticket['model']}"}}))
        first = json.loads(ws.recv(timeout=15))
        assert "setupComplete" in first, f"Google refused the setup: {str(first)[:300]}"
        ws.send(json.dumps({"realtimeInput": {"text": question}}))
        deadline = time.time() + 60
        answered = False
        while time.time() < deadline:
            msg = json.loads(ws.recv(timeout=max(1, deadline - time.time())))
            if "toolCall" in msg:
                responses = []
                for call in msg["toolCall"].get("functionCalls", []):
                    result["tools"].append(call["name"])
                    answer = my_orchard(token) if call["name"] == "get_my_orchard" else {"error": "unknown_tool"}
                    result["zones"] = answer
                    responses.append({"id": call.get("id", ""), "name": call["name"], "response": answer})
                ws.send(json.dumps({"toolResponse": {"functionResponses": responses}}))
            content = msg.get("serverContent") or {}
            for part in (content.get("modelTurn") or {}).get("parts", []):
                data = (part.get("inlineData") or {}).get("data")
                if data:
                    result["audio"] += base64.b64decode(data)
                    answered = True
            if (content.get("outputTranscription") or {}).get("text"):
                result["text"] += content["outputTranscription"]["text"]
                answered = True
            usage = msg.get("usageMetadata")
            if usage:
                result["tokens"] = (usage.get("promptTokenCount", 0), usage.get("responseTokenCount", 0))
            if content.get("turnComplete") and answered:
                break
    wav = os.path.join(tempfile.gettempdir(), f"looz_voice_{ticket['id'][:8]}.wav")
    with wave.open(wav, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(24000)
        w.writeframes(bytes(result["audio"]))
    result["wav"] = wav
    result["audio_seconds"] = len(result["audio"]) / 48000
    return result


def end(token: str, ticket: dict, result: dict) -> dict:
    r = app_rpc(token, "voice_end", {
        "p_id": ticket["id"], "p_reason": "farmer", "p_questions": 1, "p_tool_calls": len(result["tools"]),
        "p_posts": 0, "p_tokens_in": result["tokens"][0], "p_tokens_out": result["tokens"][1]})
    assert r.status_code == 200, r.text
    return r.json()


def test_who_may_talk(free_farmer):
    assert voice_token(None)[0] == 401
    assert voice_token(free_farmer) == (200, {"error": "not_paid"})


@pytest.mark.parametrize("lang, question", [
    ("ar", "شنوّة حال السانية؟"),
    ("fr", "Comment va mon verger ?"),
])
def test_milestone_1_question_answered_with_his_orchard(farmer, lang, question):
    r = app_rpc(farmer, "voice_set_consent", {"p_on": True})
    assert r.status_code == 200 and r.json() is True, r.text
    quota = app_rpc(farmer, "my_voice_quota", {}).json()
    print(f"\n   quota: {quota}")
    assert quota["enabled"] and quota["paid"] and quota["consent"]
    if quota["left_seconds"] < 30:
        pytest.skip("22 777 001 used his minutes of today")

    status, ticket = voice_token(farmer, lang)
    assert status == 200 and "token" in ticket, ticket
    assert ticket["seconds"] >= 30 and ticket["model"].startswith("gemini")
    t0 = time.time()
    try:
        result = converse(ticket, question, farmer)
    finally:
        took = time.time() - t0
    left = end(farmer, ticket, result)
    print(f"   question ({lang}): {question}")
    print(f"   tools called: {result['tools']}")
    print(f"   zones sent to Gemini: {json.dumps(result['zones'], ensure_ascii=False)[:900]}")
    print(f"   ANSWER of لوز: {result['text']}")
    print(f"   voice: {result['audio_seconds']:.1f} s -> {result['wav']}   ({took:.1f} s in all)")
    print(f"   tokens (last answer): in {result['tokens'][0]}, out {result['tokens'][1]}")
    print(f"   voice_end: {left}")

    assert "get_my_orchard" in result["tools"], "Gemini did not look at his orchard"
    assert result["audio_seconds"] > 0.5, "no voice"
    assert result["text"].strip(), "no text of the answer"
    if lang == "ar":
        assert any("؀" <= c <= "ۿ" for c in result["text"]), "the answer is not in Arabic letters"
    row = app_get(farmer, f"voice_sessions?id=eq.{ticket['id']}&select=*")[0]
    assert row["end_reason"] == "farmer" and 20 <= row["charged_seconds"] <= ticket["seconds"]
    assert row["tool_calls"] == len(result["tools"])
    # Nothing of the words is in the table.
    assert question not in json.dumps(row, ensure_ascii=False)
    assert result["text"][:10] not in json.dumps(row, ensure_ascii=False)
