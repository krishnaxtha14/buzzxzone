
from flask import Flask, render_template, redirect, request, session, jsonify
import psycopg2
import psycopg2.extras
from werkzeug.security import generate_password_hash, check_password_hash
from dotenv import load_dotenv
import random
import os
import smtplib
from datetime import datetime, timedelta
from email.mime.text import MIMEText
from urllib.parse import quote

load_dotenv()

# ─────────────────────────────────────────────
# CONFIG
# ─────────────────────────────────────────────
BASE_DIR        = os.path.dirname(os.path.abspath(__file__))
GODOT_GAME_HTML = "game.html"

app = Flask(__name__)
app.secret_key = os.environ.get("FLASK_SECRET_KEY", "supersecretkey-change-in-production")


# ─────────────────────────────────────────────
# DATABASE (PostgreSQL via Supabase)
# ─────────────────────────────────────────────
def get_db():
    url = os.environ.get("DATABASE_URL")
    if not url:
        raise RuntimeError("DATABASE_URL environment variable is not set")
    conn = psycopg2.connect(url, sslmode="require",
                            connect_timeout=8,
                            keepalives=1,
                            keepalives_idle=30)
    return conn


def get_cur(conn):
    """Return a dict-cursor so rows are accessible by column name."""
    return conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)


def init_db():
    """Create the users table if it doesn't exist."""
    conn = get_db()
    cur  = conn.cursor()          # plain cursor is fine here (no row access)
    cur.execute("""
        CREATE TABLE IF NOT EXISTS users (
            id              SERIAL PRIMARY KEY,
            username        TEXT NOT NULL,
            email           TEXT NOT NULL UNIQUE,
            password        TEXT NOT NULL
        )
    """)
    conn.commit()
    conn.close()


try:
    init_db()
except Exception as _e:
    print("[cyber] init_db warning:", _e)


# ─────────────────────────────────────────────
# EMAIL (OTP via Gmail)
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
        print("[cyber] Email error:", e)
        print(f"[cyber] (DEV) OTP for {to_email} is: {otp}")


# ─────────────────────────────────────────────
# HEALTH CHECK  (visit /health to verify DB)
# ─────────────────────────────────────────────
@app.route("/health")
def health():
    try:
        conn = get_db()
        conn.cursor().execute("SELECT 1")
        conn.close()
        return jsonify({"status": "ok", "database": "connected"})
    except Exception as e:
        return jsonify({"status": "error", "database": str(e)}), 500


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
        cur  = get_cur(conn)
        try:
            cur.execute(
                "INSERT INTO users(username, email, password) VALUES(%s, %s, %s)",
                (request.form["username"],
                 request.form["email"],
                 generate_password_hash(request.form["password"])),
            )
            conn.commit()
        except psycopg2.IntegrityError:
            conn.rollback()
            error = "Email already exists!"
        finally:
            conn.close()
        if not error:
            return redirect("/login")
    return render_template("register.html", error=error)


@app.route("/login", methods=["GET", "POST"])
def login():
    error = ""
    email = ""
    if request.method == "POST":
        email = request.form["email"]
        conn = get_db()
        cur  = get_cur(conn)
        cur.execute(
            "SELECT * FROM users WHERE email = %s",
            (email,)
        )
        user = cur.fetchone()
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
    return render_template("login.html", error=error, email=email)


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
        cur  = get_cur(conn)
        cur.execute(
            "SELECT * FROM users WHERE email = %s",
            (request.form["email"],)
        )
        user = cur.fetchone()
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
            cur  = get_cur(conn)
            cur.execute(
                "UPDATE users SET password = %s WHERE id = %s",
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
    return render_template(
        "dashboard.html",
        username=session.get("username", "PLAYER"),
    )


# ─────────────────────────────────────────────
# GAME
# ─────────────────────────────────────────────
@app.route("/games/cybersecurity")
def cybersecurity_game():
    if "user_id" not in session:
        return redirect("/login")
    username = session.get("username", "PLAYER")
    return redirect(f"/static/godot/{GODOT_GAME_HTML}?user={quote(username)}")


# ─────────────────────────────────────────────
if __name__ == "__main__":
    app.run(debug=True)
