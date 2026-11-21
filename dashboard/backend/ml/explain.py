"""The farmer's explanation of a prediction, written by a small Groq model in
Tunisian Derja (Arabic letters) AND simple French, from FACTS only.

- Made only when the prediction CHANGES (state, how sure, the 3 main reasons):
  the same key reuses the last text (kept in ml_latest), so we stay far inside
  Groq's free limits (1,000 requests a day, 8,000 tokens a minute per model).
- Every answer is checked: JSON, both languages, short, no Latin letters in the
  Arabic, NO number at all (the app shows the readings next to the text, so a
  number can never be invented or old), no pesticide / product / dose word. A wrong answer, a refusal or no answer = no text: the app then writes a
  simple text from the codes (ARB files).
- The logs say only "groq ok" / "groq refused: <reason code>", never a text,
  never the key.
"""
from __future__ import annotations

import json
import logging
import re
import time
from collections import deque
from dataclasses import dataclass

import httpx

from .factors import factor_text

log = logging.getLogger("looz.ml")
GROQ_URL = "https://api.groq.com/openai/v1/chat/completions"
PROMPT_VERSION = "p2"

SYSTEM_PROMPT = """You write short messages for Tunisian almond farmers in the app "Looz". Many farmers read with difficulty: use very simple, everyday words and short sentences.

You get FACTS (JSON) about ONE zone of the farmer's orchard: what our model predicts ("state"), how sure it is ("certainty": "likely" or "unsure"), the main reasons ("factors", already in simple words) and the latest sensor readings.

Write the same message twice:
- "ar": Tunisian Derja (the Tunisian dialect) written in Arabic letters, like a friendly farmer from Sfax talks: words like "الشجر", "السقي", "الترْبة", "برشا", "شوية", "الليلة", "توّا", "ما ثماش", "باش". Not Modern Standard Arabic, not Egyptian. No French or Latin letters. Write the zone exactly as in "zone_ar".
- "fr": simple French (short sentences, "vous"). Write the zone exactly as in "zone_fr".

For each language give:
- "text": 2 or 3 short sentences: what is happening in the zone, and why (use the factors).
- "action": ONE short sentence with ONE clear thing to do now. Start from "safe_action_ar" / "safe_action_fr" of the facts: say it in simple words, you may make it a little more precise with the facts, never add another task.

Strict rules:
1. Use ONLY the facts. Never invent a date, a disease or a cause. Write NO number and no digit at all: the app shows the readings next to your message.
2. Never name a pesticide, a fungicide, a fertilizer, a chemical, a product or a brand, and never give a dose or a quantity. Only when a treatment of the trees may be needed (a root or salt problem, a disease), tell the farmer to ask an expert: "اسأل خبير" / "demandez à un expert". Watering, checking the irrigation line or going to look at the trees need no expert.
3. If "certainty" is "unsure", say clearly that we are not sure ("موش متأكدين" / "nous ne sommes pas sûrs") and that the farmer should look at the trees himself.
4. If "state" is "none" or "no_frost", say that everything looks fine and the action is a simple check.
5. Frost risk: the action is about protecting the trees tonight in a simple way (for example go and check the zone this evening, or use the protection you usually use) — never a product.
6. No greeting, no emoji, no markdown, no lists.

Answer with JSON only, exactly this shape:
{"ar": {"text": "...", "action": "..."}, "fr": {"text": "...", "action": "..."}}"""

# The state in simple words, and a SAFE action (the model rephrases it; the app
# has the same texts in its ARB files for the template).
STATES = {
    ("stress", "none"): ("الشجر لاباس", "les arbres vont bien",
                         "كمّل كيف العادة وشوف الشجر كل نهار.", "Continuez comme d'habitude et regardez les arbres chaque jour."),
    ("stress", "water_deficit"): ("نقص في الماء", "manque d'eau",
                                  "شوف خط السقي في المنطقة هاذي واسقي كان التربة ناشفة.",
                                  "Vérifiez la ligne d'irrigation de la zone et arrosez si le sol est sec."),
    ("stress", "waterlogging"): ("ماء زايد في التربة", "trop d'eau dans le sol",
                                 "وقّف السقي في المنطقة هاذي وشوف كان الماء واقف.",
                                 "Arrêtez d'arroser cette zone et regardez si l'eau stagne."),
    ("stress", "heat"): ("سخانة قوية", "forte chaleur",
                         "اسقي في الصباح بكري ولا العشية، موش في القايلة.",
                         "Arrosez tôt le matin ou le soir, pas à midi."),
    ("stress", "frost"): ("ضرر من البرد", "dégâts du froid",
                          "امشي شوف النوّار والثمار الصغار في المنطقة هاذي.",
                          "Allez voir les fleurs et les petits fruits de cette zone."),
    ("stress", "rootzone"): ("مشكل في الجذور", "problème de racines",
                             "اسأل خبير على الجذور وملوحة الماء.",
                             "Demandez à un expert pour les racines et le sel de l'eau."),
    ("frost", "frost_risk"): ("خطر صقيع الليلة", "risque de gel cette nuit",
                              "امشي للمنطقة هاذي الليلة وحضّر الحماية اللي تستعمل فيها عادة.",
                              "Allez voir la zone ce soir et préparez la protection que vous utilisez d'habitude."),
    ("frost", "no_frost"): ("ما ثماش خطر صقيع الليلة", "pas de risque de gel cette nuit",
                            "ما تعمل شي خاص، شوف الشجر كيف العادة.",
                            "Rien de spécial, regardez les arbres comme d'habitude."),
}

BANNED = [
    # Arabic (whole words or beginnings): pesticide, medicine, fertilizer, chemical, litre, gram, kilo, dose
    "مبيد", "دواء", "ادوية", "أدوية", "سماد", "أسمدة", "اسمدة", "كيميائ", "كيماوي", "لتر", "غرام", "كيلو", "جرعة",
    "نحاس", "كبريت",
    # French
    "pesticide", "fongicide", "insecticide", "herbicide", "engrais", "dose", "litre", "gramme", "kg", "ml",
    "produit", "cuivre", "soufre", "bouillie", "traitement chimique",
]
_NUM = re.compile(r"[0-9٠-٩]+(?:[.,][0-9٠-٩]+)?")
_LATIN = re.compile(r"[A-Za-z]")


def explanation_key(model: str, state: str, certainty: str | None, factors: list[dict], zone: str) -> str:
    """Same key = same text: the zone, the state, how sure, the 3 main reasons (not the numbers)."""
    top = ",".join(f"{f['code']}:{f.get('level') or '-'}" for f in factors[:3])
    return f"{PROMPT_VERSION}|{zone}|{model}|{state}|{certainty or '-'}|{top}"


def build_facts(model: str, state: str, certainty: str | None, factors: list[dict], zone_ar: str, zone_fr: str,
                readings: dict, clock: str | None) -> dict:
    """The facts given to Groq: codes turned into words, numbers rounded as the app shows them."""
    s_ar, s_fr, a_ar, a_fr = STATES[(model, state)]
    r = {}
    for key, digits in [("soil_moisture_pct", 0), ("air_temp_c", 0), ("humidity_pct", 0), ("soil_temp_c", 0)]:
        v = readings.get(key)
        if isinstance(v, (int, float)):
            r[key] = int(round(v)) if digits == 0 else round(v, digits)
    if clock:
        r["time"] = clock
    return {
        "zone_ar": zone_ar, "zone_fr": zone_fr, "model": model, "state": state, "state_ar": s_ar, "state_fr": s_fr,
        "certainty": certainty or "unsure",
        "factors": [{"ar": factor_text(f["code"], f.get("level"), "ar"), "fr": factor_text(f["code"], f.get("level"), "fr")}
                    for f in factors[:3]],
        "safe_action_ar": a_ar, "safe_action_fr": a_fr, "readings": r,
    }


def _numbers(text: str) -> set[str]:
    out = set()
    for m in _NUM.findall(text):
        m = m.translate(str.maketrans("٠١٢٣٤٥٦٧٨٩", "0123456789")).replace(",", ".")
        out.add(m.rstrip("0").rstrip(".") if "." in m else m)
    return out


_AR_PREFIXES = ("وبال", "وال", "بال", "فال", "كال", "لل", "ال", "و", "ف", "ب", "ل", "ك")
_AR_WORD = re.compile("[" + chr(0x0621) + "-" + chr(0x064A) + "]+")


def _banned(text: str) -> bool:
    """A banned word: French as a whole word; Arabic as the START of a word once its usual prefixes
    (و ف ب ل ك ال...) are removed ("التربة" is not "لتر", "مبيدات" is "مبيد")."""
    low = text.lower()
    if any(re.search(r"\b" + re.escape(w) + r"\b", low) for w in BANNED if w.isascii()):
        return True
    arabic = [w for w in BANNED if not w.isascii()]
    for token in _AR_WORD.findall(text):
        forms = {token}
        prefix = next((p for p in _AR_PREFIXES if token.startswith(p)), "")   # the longest one (listed first)
        if prefix and len(token) - len(prefix) >= 3:
            forms.add(token[len(prefix):])
        if any(f.startswith(w) for f in forms for w in arabic):
            return True
    return False


def check_answer(answer: dict, facts: dict) -> str | None:
    """None = the answer can be shown; else the reason code why not."""
    try:
        parts = {lang: (answer[lang]["text"].strip(), answer[lang]["action"].strip()) for lang in ("ar", "fr")}
    except (KeyError, TypeError, AttributeError):
        return "shape"
    for lang, (text, action) in parts.items():
        if not text or not action or len(text) > 600 or len(action) > 300:
            return "length"
        both = text + " " + action
        if lang == "ar" and _LATIN.search(both.replace("°C", "").replace("°", "")):
            return "latin_in_arabic"
        if _banned(both):
            return "banned_word"
        if _numbers(both):
            return "number"
    return None


def parse_answer(content: str) -> dict | None:
    content = re.sub(r"<think>.*?</think>", "", content or "", flags=re.S).strip()
    content = re.sub(r"^```(?:json)?|```$", "", content.strip(), flags=re.M).strip()
    try:
        data = json.loads(content)
    except ValueError:
        m = re.search(r"\{.*\}", content, flags=re.S)
        if not m:
            return None
        try:
            data = json.loads(m.group(0))
        except ValueError:
            return None
    return data if isinstance(data, dict) else None


@dataclass
class Explanation:
    texts: dict | None        # {"ar": {"text", "action"}, "fr": {...}} or None (= the app's template)
    source: str               # "groq:<model>" or "template"
    key: str


class Explainer:
    """Calls Groq when needed, with a small budget per minute and per day."""

    def __init__(self, api_key: str, model: str, per_minute: int = 6, per_day: int = 800,
                 url: str = GROQ_URL, timeout: float = 20.0, client: httpx.Client | None = None):
        self.api_key, self.model, self.url, self.timeout = api_key, model, url, timeout
        self.per_minute, self.per_day = per_minute, per_day
        self.calls: deque[float] = deque()
        self.day_calls: deque[float] = deque()
        self.cache: dict[str, dict] = {}
        self.client = client or httpx.Client(timeout=timeout)
        self.paused_until = 0.0

    def _budget_ok(self) -> bool:
        now = time.time()
        while self.calls and now - self.calls[0] > 60:
            self.calls.popleft()
        while self.day_calls and now - self.day_calls[0] > 86400:
            self.day_calls.popleft()
        return now >= self.paused_until and len(self.calls) < self.per_minute and len(self.day_calls) < self.per_day

    def explain(self, facts: dict, key: str, previous: dict | None = None) -> Explanation:
        # 1) the same prediction as before: keep its text
        if previous and previous.get("explanation_key") == key and previous.get("explanation_ar"):
            texts = {"ar": {"text": previous["explanation_ar"], "action": previous.get("action_ar") or ""},
                     "fr": {"text": previous.get("explanation_fr") or "", "action": previous.get("action_fr") or ""}}
            return Explanation(texts, previous.get("explanation_source") or f"groq:{self.model}", key)
        if key in self.cache:
            return Explanation(self.cache[key], f"groq:{self.model}", key)
        if not self.api_key or not self.model or not self._budget_ok():
            return Explanation(None, "template", key)
        # 2) ask Groq once
        now = time.time()
        self.calls.append(now)
        self.day_calls.append(now)
        body = {"model": self.model, "temperature": 0.2, "max_tokens": 700,
                "messages": [{"role": "system", "content": SYSTEM_PROMPT},
                             {"role": "user", "content": "FACTS:\n" + json.dumps(facts, ensure_ascii=False)}],
                "response_format": {"type": "json_object"}}
        if self.model.startswith("qwen/"):
            body["reasoning_effort"] = "none"
        elif self.model.startswith("openai/"):
            body["reasoning_effort"] = "low"
        try:
            r = self.client.post(self.url, json=body, timeout=self.timeout,
                                 headers={"Authorization": f"Bearer {self.api_key}"})
        except httpx.HTTPError:
            log.warning("groq refused: network")
            return Explanation(None, "template", key)
        if r.status_code == 429:
            self.paused_until = time.time() + 60
            log.warning("groq refused: limit (429)")
            return Explanation(None, "template", key)
        if r.status_code != 200:
            log.warning("groq refused: http %s", r.status_code)
            return Explanation(None, "template", key)
        try:
            content = r.json()["choices"][0]["message"]["content"]
        except (ValueError, KeyError, IndexError, TypeError):
            log.warning("groq refused: no content")
            return Explanation(None, "template", key)
        answer = parse_answer(content)
        why = "not_json" if answer is None else check_answer(answer, facts)
        if why:
            log.warning("groq refused: %s", why)
            return Explanation(None, "template", key)
        texts = {lang: {"text": answer[lang]["text"].strip(), "action": answer[lang]["action"].strip()} for lang in ("ar", "fr")}
        self.cache[key] = texts
        if len(self.cache) > 500:
            self.cache.pop(next(iter(self.cache)))
        log.info("groq ok")
        return Explanation(texts, f"groq:{self.model}", key)
