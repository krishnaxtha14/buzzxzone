/* ═══════════════════════════════════════════════════════════════
   cyber · Auto-Play Eco Snake Quiz — game.js
   The snake plays itself. The player only answers the question.
     • Correct  → snake grows by 1, +10 points
     • Wrong    → snake shrinks by 1
     • Time out → counts as wrong, snake shrinks
     • Game over when snake length drops below MIN_LEN
     • 1 minute per question (hard cap, from server: QUESTION_TIME)
═══════════════════════════════════════════════════════════════ */

// ── Inputs from snake.html ──────────────────────────────────────
// const QUESTIONS      = [...];      ← injected as JSON
// const QUESTION_TIME  = 60;         ← seconds per question
// const POINTS_PER_Q   = 10;

// ── DOM refs ────────────────────────────────────────────────────
const canvas = document.getElementById('snake-canvas');
const ctx    = canvas.getContext('2d');

const startScreen   = document.getElementById('start-screen');
const overScreen    = document.getElementById('over-screen');
const questionBox   = document.getElementById('question-box');
const questionText  = document.getElementById('question-text');
const answerGrid    = document.getElementById('answer-grid');
const timerBar      = document.getElementById('timer-bar');

const elScore  = document.getElementById('hud-score');
const elQno    = document.getElementById('hud-qno');
const elLength = document.getElementById('hud-length');
const elTimer  = document.getElementById('hud-timer');

const overTitle   = document.getElementById('over-title');
const overMessage = document.getElementById('over-message');

// ── Canvas grid ─────────────────────────────────────────────────
const CELL = 20;
const COLS = canvas.width  / CELL;   // 25
const ROWS = canvas.height / CELL;   // 25

// ── Game-level constants ────────────────────────────────────────
const TICK_MS  = 110;    // snake auto-move speed
const MIN_LEN  = 1;      // game over if length drops below this

// ── State ───────────────────────────────────────────────────────
let snake, dir, leaf;
let score, qIndex, growPending;
let running, questionOpen;
let questionTime;
let gameLoopId, timerLoopId;

// ── Helpers ─────────────────────────────────────────────────────
const show = el => el.classList.remove('hidden');
const hide = el => el.classList.add('hidden');

function randCell() {
  return { x: Math.floor(Math.random() * COLS),
           y: Math.floor(Math.random() * ROWS) };
}
function placeLeaf() {
  let pos;
  do { pos = randCell(); }
  while (snake.some(s => s.x === pos.x && s.y === pos.y));
  leaf = pos;
}

// ── Start / restart ─────────────────────────────────────────────
function startGame() {
  // Show real question total now that QUESTIONS is loaded
  const elQtotal = document.getElementById('hud-qtotal');
  if (elQtotal) elQtotal.textContent = QUESTIONS.length;

  snake        = [{x:12,y:12},{x:11,y:12},{x:10,y:12}];
  dir          = {x:1,y:0};
  score        = 0;
  qIndex       = 0;
  growPending  = 0;
  running      = true;
  questionOpen = false;
  questionTime = QUESTION_TIME;

  hide(startScreen);
  hide(overScreen);
  hide(questionBox);

  placeLeaf();
  updateHUD();
  drawCanvas();

  clearInterval(gameLoopId);
  clearInterval(timerLoopId);
  gameLoopId  = setInterval(tick,      TICK_MS);
  timerLoopId = setInterval(tickTimer, 1000);

  // Open the first question immediately so the player can start scoring.
  openQuestion();
}

// ── Auto-pilot — pick a safe next direction ─────────────────────
function chooseDirection() {
  const head = snake[0];
  // Prefer moving toward the leaf, but only choose safe directions.
  const candidates = [
    {x: 1, y: 0}, {x: -1, y: 0}, {x: 0, y: 1}, {x: 0, y: -1},
  ].filter(d => !(d.x === -dir.x && d.y === -dir.y));   // no 180° turn

  const safe = candidates.filter(d => {
    const nx = head.x + d.x, ny = head.y + d.y;
    if (nx < 0 || nx >= COLS || ny < 0 || ny >= ROWS) return false;
    // Allow stepping onto the tail tip (it will move).
    return !snake.slice(0, -1).some(s => s.x === nx && s.y === ny);
  });

  if (safe.length === 0) return dir;   // no safe move — keep going (will die)

  // Score each safe move by Manhattan distance to leaf (lower is better).
  safe.sort((a, b) => {
    const da = Math.abs(head.x + a.x - leaf.x) + Math.abs(head.y + a.y - leaf.y);
    const db = Math.abs(head.x + b.x - leaf.x) + Math.abs(head.y + b.y - leaf.y);
    return da - db;
  });
  return safe[0];
}

// ── Auto-play tick ──────────────────────────────────────────────
function tick() {
  if (!running) return;
  // Snake keeps slithering even while a question is open.
  dir = chooseDirection();
  const head = { x: snake[0].x + dir.x, y: snake[0].y + dir.y };

  // Safety: if we somehow ran into wall/self, just wrap or skip.
  if (head.x < 0 || head.x >= COLS || head.y < 0 || head.y >= ROWS) return;
  if (snake.some(s => s.x === head.x && s.y === head.y)) return;

  snake.unshift(head);

  // Re-place leaf when reached (visual only, no scoring here).
  if (head.x === leaf.x && head.y === leaf.y) placeLeaf();

  if (growPending > 0) growPending--;
  else                 snake.pop();

  drawCanvas();
  updateHUD();
}

// ── Per-question timer (1 minute) ───────────────────────────────
function tickTimer() {
  if (!running || !questionOpen) return;
  questionTime--;
  updateTimerBar();
  updateTimerText();
  if (questionTime <= 0) {
    // Time up — counts as wrong.
    onWrong(true);
  }
}

// ── Open the next question ──────────────────────────────────────
function openQuestion() {
  if (qIndex >= QUESTIONS.length) {
    return endGame('🏆 You answered every question!', true);
  }
  questionOpen = true;
  questionTime = QUESTION_TIME;

  const q = QUESTIONS[qIndex];
  questionText.textContent = q.q;

  answerGrid.innerHTML = '';
  q.answers.forEach((ans, i) => {
    const btn = document.createElement('button');
    btn.className   = 'ans-btn';
    btn.textContent = ans;
    btn.addEventListener('click', () => handleAnswer(i));
    answerGrid.appendChild(btn);
  });

  updateTimerBar();
  updateTimerText();
  show(questionBox);
}

// ── Player answers ──────────────────────────────────────────────
function handleAnswer(index) {
  if (!questionOpen) return;
  questionOpen = false;   // block timer from firing a wrong answer on the same question
  const q       = QUESTIONS[qIndex];
  const correct = (index === q.correct);

  const btns = answerGrid.querySelectorAll('.ans-btn');
  btns.forEach(b => b.disabled = true);
  btns[index].classList.add(correct ? 'correct' : 'wrong');
  if (!correct) btns[q.correct].classList.add('correct');

  setTimeout(() => {
    if (correct) onCorrect();
    else         onWrong(false);
  }, 600);
}

// ── Correct: +10, grow ──────────────────────────────────────────
function onCorrect() {
  score       += POINTS_PER_Q;
  growPending += 1;
  // Save the running score immediately so partial plays still unlock memory.
  saveScore(score);
  continueAfterQuestion();
}

// ── POST score to server (used incrementally + on game over) ────
function saveScore(currentScore) {
  try {
    return fetch('/api/submit_score', {
      method:      'POST',
      credentials: 'same-origin',
      keepalive:   true,
      headers:     { 'Content-Type': 'application/json' },
      body:        JSON.stringify({ score: currentScore, source: 'snake' }),
    }).then(r => r.json()).catch(err => {
      console.warn('[cyber] saveScore failed:', err);
      return null;
    });
  } catch (e) { console.warn('[cyber] saveScore threw:', e); return Promise.resolve(null); }
}

// ── Wrong (or time-out): shrink ─────────────────────────────────
function onWrong(timeOut) {
  if (snake.length > MIN_LEN) snake.pop();   // shrink by 1
  if (snake.length <= MIN_LEN) {
    return endGame(
      timeOut
        ? '⏰ Time ran out! The snake shrank away.'
        : '😢 Too many wrong answers — the snake is gone!',
      false
    );
  }
  continueAfterQuestion();
}

// ── Continue to next question ───────────────────────────────────
function continueAfterQuestion() {
  qIndex++;
  questionOpen = false;
  questionTime = QUESTION_TIME;
  hide(questionBox);
  updateHUD();
  drawCanvas();

  if (qIndex >= QUESTIONS.length) {
    return endGame('🏆 You completed every question!', true);
  }
  // Small breather between questions
  setTimeout(openQuestion, 600);
}

// ── End game (and submit score to server) ───────────────────────
function endGame(message, win) {
  running      = false;
  questionOpen = false;
  clearInterval(gameLoopId);
  clearInterval(timerLoopId);
  hide(questionBox);

  overTitle.className   = win ? 'overlay-title yellow' : 'overlay-title red';
  overTitle.textContent = win ? '🏆 QUEST COMPLETE!'    : '💀 GAME OVER';
  overMessage.innerHTML = `${message}<br><br>
    Score: <strong>${score}</strong> &nbsp;|&nbsp;
    Questions answered: <strong>${qIndex}</strong>/${QUESTIONS.length}`;
  show(overScreen);

  saveScore(score).then(data => {
    if (!data || !data.ok) return;
    const info = document.createElement('p');
    info.style.cssText = 'margin-top:12px;color:var(--muted);font-size:0.9rem;';
    info.innerHTML = `Best score: <strong style="color:var(--lime)">${data.high_score}</strong>` +
                     ` — unlock Memory Match at <strong>${data.threshold}</strong>.`;
    overMessage.appendChild(info);
    if (data.memory_unlocked) {
      const note = document.createElement('p');
      note.innerHTML = '🧩 <strong>Memory Match unlocked!</strong>';
      note.style.cssText = 'color:var(--lime);margin-top:8px;font-weight:700;';
      overMessage.appendChild(note);
    }
  });
}

// ── HUD ─────────────────────────────────────────────────────────
function updateHUD() {
  elScore.textContent  = score;
  elQno.textContent    = Math.min(qIndex + 1, QUESTIONS.length);
  elLength.textContent = snake ? snake.length : 3;
  updateTimerText();
  updateTimerBar();
}
function updateTimerText() {
  const m = Math.floor(questionTime / 60);
  const s = questionTime % 60;
  elTimer.textContent = String(m).padStart(2,'0') + ':' + String(s).padStart(2,'0');
}
function updateTimerBar() {
  const pct = (questionTime / QUESTION_TIME) * 100;
  timerBar.style.width = pct + '%';
  timerBar.className   = 'timer-bar' +
    (pct < 25 ? ' danger' : pct < 50 ? ' warn' : '');
}

// ── Draw ────────────────────────────────────────────────────────
function drawCanvas() {
  ctx.fillStyle = '#06120e';
  ctx.fillRect(0, 0, canvas.width, canvas.height);

  ctx.strokeStyle = 'rgba(74,222,128,0.06)';
  ctx.lineWidth   = 1;
  for (let x = 0; x <= COLS; x++) {
    ctx.beginPath(); ctx.moveTo(x*CELL,0); ctx.lineTo(x*CELL,canvas.height); ctx.stroke();
  }
  for (let y = 0; y <= ROWS; y++) {
    ctx.beginPath(); ctx.moveTo(0,y*CELL); ctx.lineTo(canvas.width,y*CELL); ctx.stroke();
  }

  if (leaf) {
    ctx.fillStyle  = '#4ade80';
    ctx.shadowColor= '#4ade80';
    ctx.shadowBlur = 16;
    ctx.beginPath();
    ctx.arc(leaf.x*CELL + CELL/2, leaf.y*CELL + CELL/2, CELL/2 - 3, 0, Math.PI*2);
    ctx.fill();
    ctx.shadowBlur = 0;
    ctx.font         = `${CELL - 4}px serif`;
    ctx.textAlign    = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillStyle    = '#065f35';
    ctx.fillText('🌿', leaf.x*CELL + CELL/2, leaf.y*CELL + CELL/2);
  }

  if (snake) {
    snake.forEach((part, i) => {
      const isHead   = i === 0;
      ctx.fillStyle  = isHead ? '#4ade80' : '#22c55e';
      ctx.shadowColor= isHead ? '#4ade80' : '#16a34a';
      ctx.shadowBlur = isHead ? 14 : 6;
      const r = isHead ? 5 : 3;
      roundRect(ctx, part.x*CELL + 2, part.y*CELL + 2, CELL - 4, CELL - 4, r);
      ctx.fill();
      ctx.shadowBlur = 0;
    });
  }
}
function roundRect(c, x, y, w, h, r) {
  c.beginPath();
  c.moveTo(x + r, y);
  c.lineTo(x + w - r, y); c.quadraticCurveTo(x + w, y, x + w, y + r);
  c.lineTo(x + w, y + h - r); c.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
  c.lineTo(x + r, y + h); c.quadraticCurveTo(x, y + h, x, y + h - r);
  c.lineTo(x, y + r); c.quadraticCurveTo(x, y, x + r, y);
  c.closePath();
}

// ── Initial blank draw ──────────────────────────────────────────
(function initDraw() {
  ctx.fillStyle = '#06120e';
  ctx.fillRect(0, 0, canvas.width, canvas.height);
})();
