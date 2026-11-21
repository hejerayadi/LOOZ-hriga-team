# Milestone 3 — our own leaf model (RF-DETR) in Roboflow

> **Update 19 November 2026**: the app now uses **Gemini vision** (`gemini-3.6-flash`, PROJECT_STATUS.md
> section 16): 4 / 4 diseases found and 0 / 5 false alarms on the same 9 photos. This plan stays for
> later: our own model, trained on expert-confirmed photos of farmers who said yes (the "data
> flywheel" in section 16).

**Why**: on our 9 test photos (15 November 2026), the public model `almond-diseases-detection-l7tfx/2`
found **0 of 4** diseases and gave 1 false alarm (olive leaf); the SAM 3 workflow found at most 2 of 4.
Neither passes the jury rule. We train our own model.

**The jury rule** (agreed): at least **3 of the 4** diseased photos found as some disease, and at most
**1 false alarm** on the 5 "none" photos (healthy almond, autumn almond, olive, blossoms, green
picture). Checked with `python tools/diagnosis_eval.py model <model id>` (from `dashboard/backend`).

**Cost**: 1 Roboflow credit = 30 minutes of GPU training = 1,000 auto-labelled images. One training
of RF-DETR Small ≈ 45–90 minutes ≈ **2–3 credits**; auto-labelling 1,000 images ≈ 1 credit. The Free
Tier (10 credits a month) is enough. Using the model in the app costs the same as today.

**Time**: setting up and checking the labels ≈ 1–2 days; training ≈ 1–2 hours; the check ≈ 1 hour.
Real photos from Sfax / Sidi Bouzid / Kasserine come later: in mid-November the almond leaves are
falling; the diseases show best in **spring** (leaf curl at the new leaves in March–April, shot hole
after the spring rains). So: version 1 now with the existing photos, version 2 in spring with field
photos.

**Why RF-DETR**: its sizes Nano, Small, Medium and Large are **Apache 2.0** (free for commercial use,
also on the phone, offline, later). Don't train YOLO models: their weights need a paid licence to run
outside Roboflow.

---

## The steps (you, in Roboflow — workspace `hajer-ayadi-obltz`)

### 1. Check the licence of the public dataset
Open https://universe.roboflow.com/poker-chips-annotation/almond-diseases-detection-l7tfx and look at
**License** (right side of the page) and at the **Versions** (how many images version 11 has).
- **CC BY 4.0, MIT, Public Domain**: we may copy it (we write its author in PROJECT_STATUS.md).
- **Nothing written / private / "no derivatives"**: don't copy it; tell me, we start from our own
  photos only.

### 2. Create our project
Projects › **New Project** › type **Object Detection** › name `looz-almond-leaves` › what you detect:
`leaf disease` › create the 3 classes with **exactly** these names: `shot_hole`, `leaf_curl`,
`leaf_spot` (the app knows only these codes).

### 3. Copy the public dataset (only if step 1 allows it)
On its Universe page › **Download Dataset** / **Fork Dataset** › version **11** › into
`looz-almond-leaves`. Check in **Classes** that the 3 names are the same (rename if needed).

### 4. Add "nothing here" photos (about 100 to 150)
Upload photos with **no disease**: healthy almond leaves, autumn almond leaves, olive leaves, other
trees (fig, vine, citrus), soil, stones, flowers, a hand. For each: **Annotate** › **Mark Null** (no box).
These teach the model to say nothing on an olive leaf. You can use the 7 photos of
`dashboard/backend/tools/test_photos/` **only as a test** (never upload them: the test must stay
unseen by the model).

### 5. Check the boxes (most important)
In **Annotate**, open each image of the public dataset: a box must cover each hole / spot / curled
part, with the right class. Fix or delete wrong boxes. For new sick photos, use **Auto Label**
(prompts: `holes in leaf` → shot_hole, `brown spots on leaf` → leaf_spot, `curled red leaf` →
leaf_curl), then check every box by hand. If possible, ask an agronomist to confirm the sick photos.

### 6. Make a version
**Generate** › split **Train 70 % / Valid 20 % / Test 10 %** › Preprocessing: **Auto-Orient**,
**Resize 640 × 640** › Augmentations: **Flip horizontal**, **Rotation ±15°**, **Brightness ±20 %**,
**Blur up to 1 px** › outputs **×3** › **Create**.

### 7. Train
On the version › **Train Model** › **Custom Training** › architecture **RF-DETR** › size **Small** ›
checkpoint **COCO** › start. Roboflow sends an e-mail when it is done (about 1 hour).

### 8. Read the results
On the model page: **mAP@50**, **Precision**, **Recall**, and per class. Aim: recall ≥ 70 % and
precision ≥ 70 % for each disease on the test split. Send me these numbers and the **model ID**
(like `looz-almond-leaves-xxxxx/1`).

### 9. I check it, you switch it on
1. I run `python tools/diagnosis_eval.py model looz-almond-leaves-xxxxx/1` on our 9 photos (the jury
   rule) — the key stays only in `dashboard/backend/.env` for that time.
2. If it passes: Supabase › Edge Functions › Secrets › `ROBOFLOW_MODEL` = `looz-almond-leaves-xxxxx/1`.
   **No new app, no new deployment**: the function `diagnose` already reads this secret.
3. I check it live with 22 777 001, adjust the two thresholds in `app_settings` if needed
   (`diagnosis_likely` 0.65, `diagnosis_unsure` 0.40), and build "one result per class + every box
   drawn" (useful once the model finds several diseases).

### Later (version 2, spring)
Field photos of sick almond leaves (Sfax, Sidi Bouzid, Kasserine), confirmed by an agronomist. The
photos farmers send in the app are used **only** if they said "yes" (not built yet).
