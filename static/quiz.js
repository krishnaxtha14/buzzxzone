/* ═══════════════════════════════════════════════════════════════
   Cyber · Quiz Engine (math / cyber)
     • 20 seconds per question
     • 10 points per correct answer
     • Math: 2 attempts — hint shown after 2nd wrong
     • Tutorial modal before quiz starts
     • Click ripple feedback on every button
═══════════════════════════════════════════════════════════════ */

// ── Tutorial content per category + difficulty ───────────────
const TUTORIAL_DATA = {
  math: {
    easy: {
      icon: '🖐️',
      title: 'Counting & Basic Maths',
      tips: [
        'Use your fingers to count for adding and subtracting',
        'For 3 + 2: start at 3, count up 2 → <strong>5</strong>',
        'For 7 − 3: start at 7, count back 3 → <strong>4</strong>',
        'Adding <strong>0</strong> never changes the number',
        'Multiplying by <strong>1</strong> always stays the same'
      ],
      example: 'Q: What is 4 + 3?\n→ Start at 4, count up: 5, 6, 7\n→ Answer: <strong>7</strong> ✅',
      trick: '🖐️ Your fingers are your best calculator!'
    },
    medium: {
      icon: '🧮',
      title: 'BODMAS & Times Tables',
      tips: [
        '<strong>BODMAS</strong>: Brackets → Orders → ÷ → × → + → −',
        'Multiply and divide <strong>BEFORE</strong> adding and subtracting',
        '9× trick: 9×7 → (7−1=6) and (9−6=3) → <strong>63</strong>',
        '25% = ¼ of the number (divide by 4)',
        'For fractions: find a common denominator first'
      ],
      example: 'Q: What is 5 + 2 × 6?\n→ Multiply first: 2×6 = 12\n→ Then add: 5+12 = <strong>17</strong> ✅',
      trick: '🎯 BODMAS saves the day — multiply before you add!'
    },
    hard: {
      icon: '⚗️',
      title: 'Algebra & Advanced Maths',
      tips: [
        'Algebra: get <em>x</em> alone — move numbers to the other side (flip the sign)',
        '3x + 7 = 22 → 3x = 15 → x = <strong>5</strong>',
        'Powers: 2³ = 2×2×2 = <strong>8</strong>',
        'Negative × Negative = <strong>Positive</strong>: (−3)² = 9',
        'BODMAS applies to all: powers before ×, × before +'
      ],
      example: 'Q: Solve 2x − 4 = 10\n→ Add 4 both sides: 2x = 14\n→ Divide by 2: x = <strong>7</strong> ✅',
      trick: '⚖️ Balance the equation — same operation on both sides!'
    }
  },
  cyber: {
    easy: {
      icon: '🔐',
      title: 'Online Safety Basics',
      tips: [
        '<strong>NEVER</strong> share your password — not even with friends',
        'Strong password = UPPER + lower + Numb3rs + Symb@ls',
        'HTTPS + padlock 🔒 = safer website',
        'If in doubt, do <strong>NOT</strong> click — ask a trusted adult',
        'Log out of accounts when finished, especially shared devices'
      ],
      example: 'Weak: "password123"\nStrong: "G@rden#Bl00m2026!"\nWhy? Long, mixed types, no real words ✅',
      trick: '🔐 Think BEFORE you click!'
    },
    medium: {
      icon: '🎣',
      title: 'Phishing & Cyber Threats',
      tips: [
        '<strong>Phishing</strong>: fake messages to trick you into revealing data',
        'Red flags: urgency, strange links, spelling errors, unknown senders',
        '<strong>2FA</strong> adds a second verification step — much safer!',
        '<strong>VPN</strong> encrypts your connection on public Wi-Fi',
        'Always hover over links before clicking — check the real URL'
      ],
      example: 'Email: "URGENT! Account suspended. Click here!"\n→ Suspicious! Visit the real website directly ✅',
      trick: '🎣 Phishing tries to hook you — verify before you trust!'
    },
    hard: {
      icon: '🛡️',
      title: 'Advanced Cybersecurity',
      tips: [
        '<strong>AES-256</strong>: gold-standard symmetric encryption',
        '<strong>Zero-day</strong>: unknown vulnerability — no patch exists yet',
        'CIA Triad: <strong>C</strong>onfidentiality, <strong>I</strong>ntegrity, <strong>A</strong>vailability',
        '<strong>CSRF</strong>: forges requests using your logged-in session',
        'Defence in depth = <strong>multiple layered</strong> security controls'
      ],
      example: 'Attack: SQL Injection\nInput: \' OR \'1\'=\'1\nEffect: Bypass login / dump DB\nDefence: Parameterised queries ✅',
      trick: '🛡️ Think like an attacker to defend like a pro!'
    }
  }
};

// ── DOM references ────────────────────────────────────────────
const elTutOverlay = document.getElementById('tutorial-overlay');
const elTutIcon    = document.getElementById('tut-icon');
const elTutTitle   = document.getElementById('tut-title');
const elTutTips    = document.getElementById('tut-tips');
const elTutExample = document.getElementById('tut-example');
const elTutTrick   = document.getElementById('tut-trick');

const elQuizCard   = document.getElementById('quiz-card');
const elQuestion   = document.getElementById('quiz-question');
const elAnswers    = document.getElementById('quiz-answers');
const elScore      = document.getElementById('quiz-score');
const elQno        = document.getElementById('quiz-qno');
const elQtotal     = document.getElementById('quiz-qtotal');
const elTimer      = document.getElementById('quiz-timer');
const elBar        = document.getElementById('quiz-bar');
const elDone       = document.getElementById('quiz-done');
const elDoneMsg    = document.getElementById('quiz-done-msg');
const elTryAgain   = document.getElementById('try-again-msg');
const elHintBox    = document.getElementById('quiz-hint');
const elHintText   = document.getElementById('hint-text');

// ── State ─────────────────────────────────────────────────────
let qIndex      = 0;
let score       = 0;
let timeLeft    = QUESTION_TIME;
let timerLoopId = null;
let answered    = false;
let wrongCount  = 0;

elQtotal.textContent = QUESTIONS.length;

// ── Tutorial ──────────────────────────────────────────────────
function buildTutorial() {
  const cat  = TUTORIAL_DATA[QUIZ_CATEGORY];
  const data = cat ? cat[QUIZ_DIFFICULTY] : null;
  if (!data) { startQuiz(); return; }

  elTutIcon.textContent      = data.icon;
  elTutTitle.textContent     = data.title;
  elTutTips.innerHTML        = data.tips.map(t => `<div class="tut-tip">▸ ${t}</div>`).join('');
  elTutExample.innerHTML     = `<pre class="tut-example-pre">${data.example}</pre>`;
  elTutTrick.innerHTML       = `<div class="tut-trick-badge">${data.trick}</div>`;
}

function startQuiz() {
  elTutOverlay.classList.add('hidden');
  elQuizCard.classList.remove('hidden');
  loadQuestion();
}

// ── Timer ─────────────────────────────────────────────────────
function startTimer() {
  timeLeft = QUESTION_TIME;
  updateTimer();
  clearInterval(timerLoopId);
  timerLoopId = setInterval(() => {
    timeLeft--;
    updateTimer();
    if (timeLeft <= 0) {
      clearInterval(timerLoopId);
      if (!answered) handleAnswer(-1, true);
    }
  }, 1000);
}

function updateTimer() {
  const s = Math.max(0, timeLeft);
  elTimer.textContent = '00:' + String(s).padStart(2, '0');
  const pct = (s / QUESTION_TIME) * 100;
  elBar.style.width = pct + '%';
  elBar.className   = 'timer-bar' + (pct < 25 ? ' danger' : pct < 50 ? ' warn' : '');
}

// ── Question loader ───────────────────────────────────────────
function loadQuestion() {
  if (qIndex >= QUESTIONS.length) return finishQuiz();
  answered   = false;
  wrongCount = 0;
  elTryAgain.classList.add('hidden');
  elHintBox.classList.add('hidden');

  const q = QUESTIONS[qIndex];
  elQno.textContent      = qIndex + 1;
  elQuestion.textContent = q.q;
  elAnswers.innerHTML    = '';

  q.answers.forEach((ans, i) => {
    const btn = document.createElement('button');
    btn.className   = 'ans-btn';
    btn.textContent = ans;
    btn.addEventListener('click', (e) => { addRipple(btn, e); handleAnswer(i, false); });
    elAnswers.appendChild(btn);
  });
  startTimer();
}

// ── Answer handler (2-attempt system for math) ────────────────
function handleAnswer(index, timeOut) {
  if (answered) return;

  const q       = QUESTIONS[qIndex];
  const correct = (index === q.correct);
  const btns    = elAnswers.querySelectorAll('.ans-btn');

  if (timeOut) {
    // Time ran out — reveal answer and move on
    answered = true;
    btns.forEach(b => b.disabled = true);
    btns[q.correct].classList.add('correct');
    elTryAgain.classList.add('hidden');
    if (q.hint && QUIZ_CATEGORY === 'math') showHint(q.hint);
    setTimeout(() => { qIndex++; loadQuestion(); }, 2000);
    return;
  }

  if (correct) {
    answered = true;
    clearInterval(timerLoopId);
    btns.forEach(b => b.disabled = true);
    btns[index].classList.add('correct');
    elTryAgain.classList.add('hidden');
    elHintBox.classList.add('hidden');
    score += POINTS_PER_Q;
    elScore.textContent = score;
    saveScore(score, false);
    pulseScore();
    if (window.playCorrectSound) window.playCorrectSound();
    setTimeout(() => { qIndex++; loadQuestion(); }, 750);
    return;
  }

  // Wrong answer
  wrongCount++;
  btns[index].classList.add('wrong');
  btns[index].disabled = true;
  shakeQuestion();
  if (window.playWrongSound) window.playWrongSound();

  if (wrongCount === 1) {
    // First wrong — give one more chance
    elTryAgain.classList.remove('hidden');
  } else {
    // Second wrong — reveal correct, show hint for math, move on
    answered = true;
    clearInterval(timerLoopId);
    btns.forEach(b => b.disabled = true);
    btns[q.correct].classList.add('correct');
    elTryAgain.classList.add('hidden');
    if (q.hint && QUIZ_CATEGORY === 'math') showHint(q.hint);
    setTimeout(() => { qIndex++; loadQuestion(); }, 2500);
  }
}

// ── Hint display ──────────────────────────────────────────────
function showHint(hintText) {
  elHintText.textContent = hintText;
  elHintBox.classList.remove('hidden');
  elHintBox.classList.add('hint-pop');
  setTimeout(() => elHintBox.classList.remove('hint-pop'), 400);
}

// ── Visual feedback helpers ───────────────────────────────────
function pulseScore() {
  elScore.classList.add('score-pulse');
  setTimeout(() => elScore.classList.remove('score-pulse'), 500);
}

function shakeQuestion() {
  elQuestion.classList.add('shake');
  setTimeout(() => elQuestion.classList.remove('shake'), 500);
}

// ── Ripple effect on click ────────────────────────────────────
function addRipple(el, event) {
  const rect   = el.getBoundingClientRect();
  const x      = event.clientX - rect.left;
  const y      = event.clientY - rect.top;
  const size   = Math.max(rect.width, rect.height);
  const ripple = document.createElement('span');
  ripple.className  = 'ripple';
  ripple.style.cssText = `left:${x - size / 2}px;top:${y - size / 2}px;width:${size}px;height:${size}px;`;
  el.appendChild(ripple);
  ripple.addEventListener('animationend', () => ripple.remove());
}

// Global ripple for sidebar links and overlay buttons
document.addEventListener('mousedown', (e) => {
  const btn = e.target.closest('a.overlay-btn, a.play-btn, button.overlay-btn, button.mem-new-btn, a.diff-card');
  if (btn) addRipple(btn, e);
});

// ── Score persistence ─────────────────────────────────────────
function saveScore(currentScore, isFinal) {
  try {
    return fetch('/api/submit_score', {
      method:      'POST',
      credentials: 'same-origin',
      keepalive:   true,
      headers:     { 'Content-Type': 'application/json' },
      body:        JSON.stringify({
        score:      currentScore,
        source:     QUIZ_CATEGORY,
        difficulty: QUIZ_DIFFICULTY,
      }),
    }).then(r => r.json()).catch(err => {
      console.warn('[cyber] saveScore failed:', err);
      return null;
    });
  } catch (e) { console.warn('[cyber] saveScore threw:', e); return Promise.resolve(null); }
}

// ── Finish ────────────────────────────────────────────────────
function finishQuiz() {
  elQuizCard.classList.add('hidden');
  elDone.classList.remove('hidden');
  elDoneMsg.innerHTML = `
    🎯 You scored <strong>${score}</strong> points
    (${Math.floor(score / POINTS_PER_Q)} of ${QUESTIONS.length} correct).
  `;
  saveScore(score, true).then(data => {
    if (data && data.ok) {
      const extra = document.createElement('p');
      extra.style.cssText = 'margin-top:14px;color:var(--muted);';
      extra.innerHTML = `Best score so far: <strong style="color:var(--green)">${data.high_score}</strong>
        — unlock Memory Match at <strong>${data.threshold}</strong>.`;
      elDoneMsg.appendChild(extra);
      if (data.memory_unlocked) {
        const note = document.createElement('p');
        note.innerHTML = '🧩 <strong>Memory Match unlocked!</strong>';
        note.style.cssText = 'color:var(--lime);margin-top:10px;font-weight:700;';
        elDoneMsg.appendChild(note);
      }
    }
  });
}

// ── Boot: build tutorial then wait for user click ────────────
buildTutorial();
