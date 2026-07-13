# 🌿 buzzXzone

A full-stack Flask web app deployed on **Vercel** with a **Supabase PostgreSQL** backend.
An OTP-authenticated dashboard with animated visuals and a capybara mascot.

Live: **[buzzxzone.vercel.app](https://buzzxzone.vercel.app)**

---

## Features

| Feature | Description |
|---|---|
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
├── app.py                        ← Flask routes, DB, OTP email, health check
├── vercel.json                   ← Vercel deployment config
├── requirements.txt              ← Python dependencies
│
├── static/
│   ├── style.css                 ← Global styles, forest theme, capybara, animations
│   └── logo.svg                  ← App logo
│
└── templates/
    ├── base.html                 ← Shared layout: neon trail, spark effects, audio
    ├── dashboard.html             ← Dashboard with capybara mascot
    ├── login.html                ← Login with OTP
    ├── register.html
    ├── verify.html                ← OTP verification
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
    id       SERIAL PRIMARY KEY,
    username TEXT NOT NULL,
    email    TEXT NOT NULL UNIQUE,
    password TEXT NOT NULL
);
```

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
