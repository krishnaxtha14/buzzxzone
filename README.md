# 🌿 buzzXzone — Eco Learning Hub

A full-stack Flask web app deployed on **Vercel** with a **Supabase PostgreSQL** backend.  
An eco-themed learning hub featuring quiz games, a memory-match mini-game, animated visuals, and a capybara mascot.

Live: **[buzzxzone.vercel.app](https://buzzxzone.vercel.app)**

---

## Features

| Feature | Description |
|---|---|
| 🐍 **Eco Snake Quiz** | Auto-playing snake — answer correctly to grow it, wrong to shrink it |
| 🧮 **Math Quiz** | Easy / Medium / Hard difficulty tiers |
| 🛡️ **Eco Cyber Quiz** | Eco-friendly cyber-security questions across three difficulty tiers |
| 🧩 **Memory Match** | Locked by default — unlocks at 100 points |
| ✨ **Neon Mouse Trail** | Glowing animated cursor trail on every page |
| 🐾 **Capybara Mascot** | Animated Capy on the dashboard — click to get messages |
| 🌿 **Forest Theme** | Dark-green vibrant UI with animated cards and floating nature symbols |
| 🔐 **OTP Auth** | Email-verified login via Gmail SMTP |

---

## Tech Stack

| Layer | Technology |
|---|---|
| Backend | Python 3 · Flask |
| Database | PostgreSQL (Supabase) via `psycopg2` |
| Frontend | HTML5 · CSS3 · Vanilla JavaScript · Canvas 2D |
| Auth | Session-based + 6-digit OTP via Gmail SMTP |
| Deployment | Vercel (serverless) |

---

## Project Structure

```
buzzxzone/
│
├── app.py                        ← Flask routes, DB, scoring, OTP email, health check
├── vercel.json                   ← Vercel deployment config
├── requirements.txt              ← Python dependencies
│
├── questions/                    ← Question banks (JSON)
│   ├── snake.json
│   ├── math_easy.json
│   ├── math_medium.json
│   ├── math_hard.json
│   ├── cyber_easy.json
│   ├── cyber_medium.json
│   └── cyber_hard.json
│
├── static/
│   ├── style.css                 ← Global styles, forest theme, capybara, animations
│   ├── logo.svg                  ← App logo
│   ├── game.js                   ← Auto-play snake engine
│   └── quiz.js                   ← Shared quiz engine (math + cyber)
│
└── templates/
    ├── base.html                 ← Shared layout: neon trail, spark effects, audio
    ├── dashboard.html            ← Game hub with capybara mascot + animated cards
    ├── snake.html                ← Eco Snake Quiz page
    ├── difficulty.html           ← Difficulty picker (math + cyber)
    ├── quiz.html                 ← Generic quiz page
    ├── memory.html               ← Memory Match (unlockable)
    ├── login.html                ← Login with OTP
    ├── register.html
    ├── verify.html               ← OTP verification
    ├── forgot.html
    ├── reset_verify.html
    └── new_password.html
```

---

## Local Development

### 1. Clone the repo

```bash
git clone https://github.com/krishnaxtha14/buzzxzone.git
cd buzzxzone
```

### 2. Install dependencies

```bash
pip install -r requirements.txt
```

`requirements.txt` contains:
```
flask>=3.0.0
werkzeug>=3.0.0
psycopg2-binary>=2.9.0
python-dotenv>=1.0.0
```

### 3. Set environment variables

Create a `.env` file in the project root:

```env
# Supabase PostgreSQL connection string
DATABASE_URL=postgresql://postgres.[ref]:[password]@aws-0-[region].pooler.supabase.com:6543/postgres

# Flask session secret (any random string)
FLASK_SECRET_KEY=your-secret-key-here

# Gmail SMTP for OTP emails (optional for local dev)
GMAIL_USER=your-email@gmail.com
GMAIL_PASSWORD=your-app-password
```

> **Note:** OTP emails are optional locally. If Gmail isn't configured, the OTP is printed to the server console instead.

### 4. Run locally

```bash
python app.py
```

Visit `http://localhost:5000`

---

## Vercel Deployment

This project is configured for Vercel serverless deployment via `vercel.json`.

### Environment Variables (set in Vercel dashboard)

| Variable | Required | Description |
|---|---|---|
| `DATABASE_URL` | ✅ Yes | Full Supabase connection string (pooler, port 6543) |
| `FLASK_SECRET_KEY` | ✅ Yes | Session signing key |
| `GMAIL_USER` | Optional | Gmail address for OTP sending |
| `GMAIL_PASSWORD` | Optional | Gmail app password |

### Check if the database is connected

After deployment, visit:

```
https://buzzxzone.vercel.app/health
```

Expected response when healthy:
```json
{"status": "ok", "database": "connected"}
```

If it returns an error, check that `DATABASE_URL` is set correctly in the Vercel dashboard and uses `sslmode=require`.

### Supabase Setup

1. Create a project at [supabase.com](https://supabase.com)
2. Go to **Project Settings → Database → Connection Pooling**
3. Copy the **Transaction pooler** connection string (port 6543)
4. Set it as `DATABASE_URL` in Vercel

The `users` table is created automatically on first startup:

```sql
CREATE TABLE IF NOT EXISTS users (
    id              SERIAL PRIMARY KEY,
    username        TEXT NOT NULL,
    email           TEXT NOT NULL UNIQUE,
    password        TEXT NOT NULL,
    high_score      INTEGER NOT NULL DEFAULT 0,
    memory_unlocked INTEGER NOT NULL DEFAULT 0
);
```

---

## Games

### 🐍 Eco Snake Quiz

The snake plays **automatically** — no player controls. Answer questions to influence it.

| Event | Result |
|---|---|
| Correct answer | Snake grows (+1 segment) · **+10 points** |
| Wrong / timeout | Snake shrinks (−1 segment) |
| Snake too short | Game over |
| Timer per question | **20 seconds** |

### 🧮 Math Quiz

Three difficulty tiers, 10 pts per correct answer, 20-second timer per question.

- **Easy** — single-digit arithmetic, simple multiplication
- **Medium** — two-digit arithmetic, tables, division
- **Hard** — BIDMAS, fractions, percentages, algebra

### 🛡️ Eco Cyber-Security Quiz

Cyber-security questions framed around eco-digital habits.

- **Easy** — phishing basics, password safety, device hygiene
- **Medium** — 2FA, fake eco-deals, HTTPS, e-waste
- **Hard** — social engineering, ransomware, encryption, supply-chain attacks

### 🧩 Memory Match

- Locked until the player's **highest score reaches 100 points**
- 4×4 grid of 16 cards (8 emoji pairs)
- Shows a progress bar on the locked card
- Configurable via `UNLOCK_THRESHOLD` in `app.py`

---

## Question Format

All questions live in `questions/*.json`:

```json
[
  {
    "q": "What does HTTPS stand for?",
    "answers": ["HyperText Transfer Protocol Secure", "High Tech Phishing System", "Hyper Transfer Protocol Standard", "HyperText Testing Protocol Suite"],
    "correct": 0
  }
]
```

| Field | Type | Description |
|---|---|---|
| `q` | string | The question text |
| `answers` | array[4] | Exactly 4 answer choices |
| `correct` | integer | 0-indexed position of the correct answer |

Questions are shuffled on every new session.

---

## Key Constants (`app.py`)

| Constant | Default | Description |
|---|---|---|
| `QUESTION_TIME_SEC` | `20` | Seconds allowed per question |
| `POINTS_PER_Q` | `10` | Points per correct answer |
| `UNLOCK_THRESHOLD` | `100` | Score needed to unlock Memory Match |

---

## Visual Features

### Neon Mouse Trail
Every page has an animated neon glow trail that follows the cursor:
- Glowing particles cycle through greens, cyans, and golds
- Connected line with shadow blur and colour-coded inner/outer rings
- Pulsing cursor dot with custom ring

### Spark Click Effect
Clicking or tapping anywhere spawns an explosion of neon sparks.

### Capybara Mascot
The dashboard features **Capy**, an animated 2D canvas capybara:
- Walking, sitting, eating, and waving animations
- Ear twitches, eye blinks, tail wag
- Click to cycle through 10 messages
- Message auto-cycles every 5 seconds

### Animated Cards
Dashboard game cards have:
- Staggered entrance animations
- Bouncing icon on idle
- Glowing top-bar reveal on hover

---

## Authentication Flow

```
Register → Login (email + password) → OTP email sent → Verify OTP → Dashboard
                                                            ↑
                                              (printed to console if email not set)
```

Password reset follows the same OTP flow via `Forgot Password`.

---

## License

MIT — free to use, modify, and deploy.
