# 🌿 pooki — Eco Learning Quiz Hub

A Flask web app featuring **pooki**: an eco-themed learning hub for ages 6-12 with
an auto-playing snake quiz, a math quiz, an eco-friendly cyber-security quiz, and
an unlockable memory-match mini-game.

---

## Project Structure

```
pooki/
│
├── app.py                          ← Flask routes, SQLite, scoring, OTP email
├── pooki.db                        ← SQLite database (auto-created on first run)
│
├── questions/                      ← All question banks (separate JSON files)
│   ├── math_easy.json
│   ├── math_medium.json
│   ├── math_hard.json
│   ├── cyber_easy.json
│   ├── cyber_medium.json
│   ├── cyber_hard.json
│   └── snake.json
│
├── static/
│   ├── style.css                   ← All visual styles
│   ├── game.js                     ← Auto-play snake engine
│   └── quiz.js                     ← Shared quiz engine (math + cyber)
│
└── templates/
    ├── base.html                   ← Shared layout (leaf background)
    ├── login.html / register.html / verify.html
    ├── forgot.html / reset_verify.html / new_password.html
    ├── dashboard.html              ← Game hub (4 cards, memory locked by default)
    ├── snake.html                  ← Auto-play snake page
    ├── difficulty.html             ← Easy / Medium / Hard picker (math + cyber)
    ├── quiz.html                   ← Generic quiz page (math + cyber)
    └── memory.html                 ← Memory Match (only reachable when unlocked)
```

---

## How to Run

### 1. Install dependencies

```bash
pip install flask werkzeug
```

### 2. Storage

pooki uses **SQLite** (`pooki.db`) — Python's built-in `sqlite3` module. No external
database server, no schema setup, no credentials. The DB file is created
automatically on first run.

### 3. (Optional) Email credentials

If you want OTP emails to send, edit `send_otp_email()` in `app.py` with your own
Gmail address and app password. If email isn't configured, the OTP is printed to
the server console so you can still log in.

### 4. Start the server

```bash
python app.py
```

Visit `http://localhost:5000`

---

## Game Features

### 🐍 Auto-Play Eco Snake Quiz
The snake is **not controlled by the player** — it slithers around on its own and
the player only answers the question on screen.

| Feature | Detail |
|---|---|
| Mode               | Fully auto-play animation — no keyboard controls |
| Timer              | **1 minute per question** (hard cap) |
| Correct answer     | Snake **grows** by 1 segment, **+10 points** |
| Wrong / time-out   | Snake **shrinks** by 1 segment |
| Game over          | Snake shrinks below its minimum length |
| Question pool      | `questions/snake.json` (eco-themed maths, shuffled each game) |

### 🧮 Math Quiz (Easy / Medium / Hard)
Player picks a difficulty, then answers a randomised pool from that tier.

- Easy: single-digit add/sub, simple multiplication
- Medium: two-digit arithmetic, multiplication tables, division
- Hard: BIDMAS, fractions, percentages, powers, simple algebra
- **1 minute per question**, **10 points per correct answer**
- Question banks: `questions/math_easy.json`, `math_medium.json`, `math_hard.json`

### 🛡️ Eco-Friendly Cyber-Security Quiz (Easy / Medium / Hard)
Cyber-security questions framed around eco-friendly digital habits (saving energy,
recycling old devices safely, spotting fake "green deal" scams, etc.)

- Easy: phishing basics, password basics, safe device habits
- Medium: 2FA, fake eco-deals, HTTPS, e-waste data wiping
- Hard: social engineering, supply-chain attacks, ransomware, encryption
- **1 minute per question**, **10 points per correct answer**
- Question banks: `questions/cyber_easy.json`, `cyber_medium.json`, `cyber_hard.json`

### 🧩 Memory Match — 🔒 LOCKED by default
The memory-match mini-game is locked when a new player logs in.

- **Unlocks** once the player's highest score reaches **100 points**
  (configurable via `UNLOCK_THRESHOLD` in `app.py`)
- The dashboard shows a 🔒 card with a progress bar toward the unlock
- Once unlocked: 4×4 grid of 16 cards (8 emoji pairs), with moves + time tracking

---

## Adding / Editing Questions

Every question lives in its own JSON file under `questions/`. The format is:

```json
[
  {
    "q": "What is 7 + 5?",
    "answers": ["10", "11", "12", "13"],
    "correct": 2
  }
]
```

- `answers` must be exactly **4** strings
- `correct` is the **0-indexed** position of the right answer (0 = first)
- Add as many questions per file as you like — they're shuffled per session

---

## Key Constants (in `app.py`)

| Constant            | Default | Meaning |
|---------------------|---------|---------|
| `QUESTION_TIME_SEC` | `60`    | Seconds allowed per question (hard cap) |
| `POINTS_PER_Q`      | `10`    | Points awarded per correct answer |
| `UNLOCK_THRESHOLD`  | `100`   | High score needed to unlock Memory Match |

---

## File Responsibilities

| File | Owns |
|---|---|
| `app.py`                  | Routes, SQLite, question loading, scoring, OTP, unlock logic |
| `questions/*.json`        | All question banks (math/cyber easy-medium-hard, snake) |
| `static/style.css`        | CSS variables, layout, card/button styles, locked-card + difficulty UI |
| `static/game.js`          | Auto-play snake engine, per-question 1-min timer, grow/shrink logic |
| `static/quiz.js`          | Shared math/cyber quiz engine, timer, score submission |
| `templates/base.html`     | Shared layout, leaf background |
| `templates/dashboard.html`| Game hub (4 cards, memory locked card with progress bar) |
| `templates/snake.html`    | Snake canvas + HUD, injects `QUESTIONS` JSON |
| `templates/difficulty.html` | Easy/Medium/Hard picker (used by both math and cyber) |
| `templates/quiz.html`     | Generic quiz page used by math + cyber |
| `templates/memory.html`   | Memory board (only reachable when unlocked) |
| Auth templates            | login, register, verify, forgot, reset_verify, new_password |
