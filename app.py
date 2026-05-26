

from flask import Flask, render_template, redirect, request, session, jsonify
import sqlite3
from werkzeug.security import generate_password_hash, check_password_hash
import random
import os
import json
import smtplib
from datetime import datetime, timedelta
from email.mime.text import MIMEText

# ─────────────────────────────────────────────
# CONFIG
# ─────────────────────────────────────────────
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
# Vercel's filesystem is read-only except /tmp; data won't persist between cold starts
DB_PATH = "/tmp/cyber.db" if os.environ.get("VERCEL") else os.path.join(BASE_DIR, "cyber.db")
QUESTIONS_DIR     = os.path.join(BASE_DIR, "questions")
QUESTION_TIME_SEC = 20            # 20 seconds per question (hard cap)
POINTS_PER_Q      = 10            # 10 points per correct answer
UNLOCK_THRESHOLD  = 100           # Best score needed to unlock memory match

app = Flask(__name__)
app.secret_key = os.environ.get("FLASK_SECRET_KEY", "supersecretkey-change-in-production")


# ─────────────────────────────────────────────
# DATABASE (SQLite — auto-created on first run)
# ─────────────────────────────────────────────
def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    """Create the users table and migrate old schemas in-place."""
    conn = get_db()
    cur  = conn.cursor()
    cur.execute("""
        CREATE TABLE IF NOT EXISTS users (
            id              INTEGER PRIMARY KEY AUTOINCREMENT,
            username        TEXT NOT NULL,
            email           TEXT NOT NULL UNIQUE,
            password        TEXT NOT NULL,
            high_score      INTEGER NOT NULL DEFAULT 0,
            memory_unlocked INTEGER NOT NULL DEFAULT 0
        )
    """)
    # Migration: if an older users table exists without these columns, add them.
    existing_cols = {row[1] for row in cur.execute("PRAGMA table_info(users)").fetchall()}
    if "high_score" not in existing_cols:
        cur.execute("ALTER TABLE users ADD COLUMN high_score INTEGER NOT NULL DEFAULT 0")
        print("[cyber] Migrated: added users.high_score column")
    if "memory_unlocked" not in existing_cols:
        cur.execute("ALTER TABLE users ADD COLUMN memory_unlocked INTEGER NOT NULL DEFAULT 0")
        print("[cyber] Migrated: added users.memory_unlocked column")
    conn.commit()
    conn.close()


init_db()


# ─────────────────────────────────────────────
# EMAIL (OTP via Gmail)
# Replace with your own Gmail address + app password.
# ─────────────────────────────────────────────
def send_otp_email(to_email, otp):
    sender_email    = os.environ.get("GMAIL_USER", "")
    sender_password = os.environ.get("GMAIL_PASSWORD", "")
    msg = MIMEText(f"Your Cyber OTP is: {otp}")
    msg["Subject"] = "Cyber Verification Code"
    msg["From"]    = sender_email
    msg["To"]      = to_email
    try:
        server = smtplib.SMTP("smtp.gmail.com", 587)
        server.starttls()
        server.login(sender_email, sender_password)
        server.send_message(msg)
        server.quit()
    except Exception as e:
        # Don't crash the app if email isn't configured.
        print("[cyber] Email error:", e)
        print(f"[cyber] (DEV) OTP for {to_email} is: {otp}")


# ─────────────────────────────────────────────
# QUESTIONS LOADER
# ─────────────────────────────────────────────
def load_questions(name):
    """Load a question bank JSON file from /questions and shuffle it."""
    path = os.path.join(QUESTIONS_DIR, f"{name}.json")
    with open(path, "r", encoding="utf-8") as f:
        pool = json.load(f)
    random.shuffle(pool)
    return pool


# ─────────────────────────────────────────────
# SCORE / UNLOCK HELPERS
# ─────────────────────────────────────────────
def update_high_score(user_id, new_score):
    """Save the user's high score and unlock memory match if threshold reached."""
    conn = get_db()
    cur  = conn.cursor()
    row  = cur.execute(
        "SELECT high_score, memory_unlocked FROM users WHERE id=?", (user_id,)
    ).fetchone()
    if row is None:
        conn.close()
        return 0, False

    best     = max(row["high_score"], int(new_score))
    unlocked = 1 if (best >= UNLOCK_THRESHOLD or row["memory_unlocked"]) else 0

    cur.execute(
        "UPDATE users SET high_score=?, memory_unlocked=? WHERE id=?",
        (best, unlocked, user_id),
    )
    conn.commit()
    conn.close()
    return best, bool(unlocked)


def get_user_progress(user_id):
    """Returns dict with high_score, memory_unlocked, threshold, progress_pct."""
    conn = get_db()
    row  = conn.execute(
        "SELECT high_score, memory_unlocked FROM users WHERE id=?", (user_id,)
    ).fetchone()
    conn.close()
    if row is None:
        return {"high_score": 0, "memory_unlocked": False,
                "threshold": UNLOCK_THRESHOLD, "progress_pct": 0}

    pct = min(100, int(row["high_score"] * 100 / UNLOCK_THRESHOLD)) if UNLOCK_THRESHOLD else 100
    return {
        "high_score":      row["high_score"],
        "memory_unlocked": bool(row["memory_unlocked"]),
        "threshold":       UNLOCK_THRESHOLD,
        "progress_pct":    pct,
    }


# ─────────────────────────────────────────────
# AUTH ROUTES
# ─────────────────────────────────────────────
@app.route("/")
def home():
    return redirect("/login")


@app.route("/register", methods=["GET", "POST"])
def register():
    error = ""
    if request.method == "POST":
        conn = get_db()
        try:
            conn.execute(
                "INSERT INTO users(username, email, password) VALUES(?,?,?)",
                (request.form["username"],
                 request.form["email"],
                 generate_password_hash(request.form["password"])),
            )
            conn.commit()
        except sqlite3.IntegrityError:
            error = "Email already exists!"
        conn.close()
        if not error:
            return redirect("/login")
    return render_template("register.html", error=error)


@app.route("/login", methods=["GET", "POST"])
def login():
    error = ""
    if request.method == "POST":
        conn = get_db()
        user = conn.execute(
            "SELECT * FROM users WHERE email=?", (request.form["email"],)
        ).fetchone()
        conn.close()
        if not user or not check_password_hash(user["password"], request.form["password"]):
            error = "Invalid credentials!"
        else:
            otp = str(random.randint(100000, 999999))
            session["otp"]        = otp
            session["otp_expiry"] = (datetime.now() + timedelta(minutes=5)).isoformat()
            session["temp_user"]  = {"id": user["id"], "username": user["username"]}
            send_otp_email(user["email"], otp)
            return redirect("/verify")
    return render_template("login.html", error=error)


@app.route("/verify", methods=["GET", "POST"])
def verify():
    if "otp" not in session:
        return redirect("/login")
    error = ""
    if request.method == "POST":
        if request.form["otp"] != session["otp"]:
            error = "Invalid OTP!"
        elif datetime.now() > datetime.fromisoformat(session["otp_expiry"]):
            error = "OTP expired!"
        else:
            user = session["temp_user"]
            session.clear()
            session["user_id"]  = user["id"]
            session["username"] = user["username"]
            return redirect("/dashboard")
    return render_template("verify.html", error=error)


@app.route("/forgot", methods=["GET", "POST"])
def forgot():
    error = ""
    if request.method == "POST":
        conn = get_db()
        user = conn.execute(
            "SELECT * FROM users WHERE email=?", (request.form["email"],)
        ).fetchone()
        conn.close()
        if not user:
            error = "Email not found!"
        else:
            otp = str(random.randint(100000, 999999))
            session["reset_otp"]    = otp
            session["reset_expiry"] = (datetime.now() + timedelta(minutes=5)).isoformat()
            session["reset_user"]   = user["id"]
            send_otp_email(request.form["email"], otp)
            return redirect("/reset_verify")
    return render_template("forgot.html", error=error)


@app.route("/reset_verify", methods=["GET", "POST"])
def reset_verify():
    if "reset_otp" not in session:
        return redirect("/forgot")
    error = ""
    if request.method == "POST":
        if request.form["otp"] != session["reset_otp"]:
            error = "Invalid OTP!"
        else:
            return redirect("/new_password")
    return render_template("reset_verify.html", error=error)


@app.route("/new_password", methods=["GET", "POST"])
def new_password():
    if "reset_user" not in session:
        return redirect("/forgot")
    error = ""
    if request.method == "POST":
        if request.form["password"] != request.form["confirm"]:
            error = "Passwords do not match!"
        else:
            conn = get_db()
            conn.execute(
                "UPDATE users SET password=? WHERE id=?",
                (generate_password_hash(request.form["password"]), session["reset_user"]),
            )
            conn.commit()
            conn.close()
            session.clear()
            return redirect("/login")
    return render_template("new_password.html", error=error)


@app.route("/logout")
def logout():
    session.clear()
    return redirect("/login")


# ─────────────────────────────────────────────
# DASHBOARD
# ─────────────────────────────────────────────
@app.route("/dashboard")
def dashboard():
    if "user_id" not in session:
        return redirect("/login")
    progress = get_user_progress(session["user_id"])
    return render_template(
        "dashboard.html",
        username=session.get("username", "PLAYER"),
        progress=progress,
    )


# ─────────────────────────────────────────────
# GAME ROUTES
# ─────────────────────────────────────────────
@app.route("/games/snake")
def snake():
    if "user_id" not in session:
        return redirect("/login")
    questions = load_questions("snake")
    return render_template(
        "snake.html",
        questions_json=json.dumps(questions),
        username=session.get("username", "PLAYER"),
        question_time=QUESTION_TIME_SEC,
        points_per_q=POINTS_PER_Q,
    )


@app.route("/games/math")
def math_picker():
    if "user_id" not in session:
        return redirect("/login")
    return render_template("difficulty.html",
                           category="math",
                           title="MATH QUIZ",
                           icon="🧮",
                           username=session.get("username", "PLAYER"))


@app.route("/games/cyber")
def cyber_picker():
    if "user_id" not in session:
        return redirect("/login")
    return render_template("difficulty.html",
                           category="cyber",
                           title="ECO CYBER-SECURITY QUIZ",
                           icon="🛡️",
                           username=session.get("username", "PLAYER"))


@app.route("/games/<category>/<difficulty>")
def play_quiz(category, difficulty):
    if "user_id" not in session:
        return redirect("/login")
    if category not in ("math", "cyber"):
        return redirect("/dashboard")
    if difficulty not in ("easy", "medium", "hard"):
        return redirect(f"/games/{category}")

    bank_name = f"{category}_{difficulty}"
    try:
        questions = load_questions(bank_name)
    except FileNotFoundError:
        return redirect(f"/games/{category}")

    title_map = {
        "math":  "MATH QUIZ",
        "cyber": "ECO CYBER-SECURITY QUIZ",
    }
    return render_template(
        "quiz.html",
        questions_json=json.dumps(questions),
        category=category,
        difficulty=difficulty,
        title=title_map[category],
        username=session.get("username", "PLAYER"),
        question_time=QUESTION_TIME_SEC,
        points_per_q=POINTS_PER_Q,
    )


@app.route("/games/memory")
def memory():
    if "user_id" not in session:
        return redirect("/login")
    progress = get_user_progress(session["user_id"])
    if not progress["memory_unlocked"]:
        # Send them back with a flash-style message in session
        session["locked_msg"] = (
            f"🔒 Memory Match is locked. Reach {progress['threshold']} points "
            f"to unlock it! (Best so far: {progress['high_score']})"
        )
        return redirect("/dashboard")
    return render_template("memory.html",
                           username=session.get("username", "PLAYER"))


# ─────────────────────────────────────────────
# SCORE SUBMISSION (called by snake/quiz JS at end of game)
# ─────────────────────────────────────────────
@app.route("/api/submit_score", methods=["POST"])
def submit_score():
    if "user_id" not in session:
        print("[cyber] submit_score: not_logged_in")
        return jsonify({"ok": False, "error": "not_logged_in"}), 401
    try:
        data       = request.get_json(silent=True) or {}
        score      = int(data.get("score", 0))
        source     = data.get("source", "unknown")
        difficulty = data.get("difficulty", "")
        best, unlocked = update_high_score(session["user_id"], score)
        print(f"[cyber] submit_score user={session['user_id']} "
              f"src={source}/{difficulty} score={score} -> best={best} unlocked={unlocked}")
        return jsonify({
            "ok":              True,
            "submitted":       score,
            "high_score":      best,
            "memory_unlocked": unlocked,
            "threshold":       UNLOCK_THRESHOLD,
        })
    except Exception as e:
        print("[cyber] submit_score ERROR:", e)
        return jsonify({"ok": False, "error": str(e)}), 500


@app.route("/api/progress")
def api_progress():
    if "user_id" not in session:
        return jsonify({"ok": False}), 401
    return jsonify({"ok": True, **get_user_progress(session["user_id"])})


# ─────────────────────────────────────────────
if __name__ == "__main__":
    app.run(debug=True)
