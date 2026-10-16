// The page works like Audra: select text, press ⌥⇧S (or play) and the player reads it,
// here with the browser's speech synthesis instead of Audra's on-device voices.
(() => {
  "use strict";

  const $ = (sel, root = document) => root.querySelector(sel);
  const $$ = (sel, root = document) => [...root.querySelectorAll(sel)];

  const SPEEDS = [0.5, 1, 1.5, 2, 2.5];
  const IDLE_TEXT = $("#player-text").textContent;
  const INTRO_SPOKEN = "Select any text on this page and press Option Shift S. Or press play to hear this sentence.";
  const HIDE_DELAY_MS = 3000;

  const player = $("#player");
  const slot = $("#player-slot");
  const textEl = $("#player-text");
  const voiceEl = $("#player-voice");
  const langChip = $("#player-lang");
  const progressEl = $("#player-progress");
  const btnPlay = $("#btn-play");
  const btnStop = $("#btn-stop");
  const btnSlower = $("#btn-slower");
  const btnFaster = $("#btn-faster");
  const speedSelect = $("#speed");

  const synth = "speechSynthesis" in window ? window.speechSynthesis : null;

  // ---------- Reader state ----------
  let state = "idle"; // idle | playing | paused
  let speed = 1;
  let reading = null; // { text, lang, sentences, pos, row }
  let epoch = 0; // bumped on every restart so callbacks from cancelled utterances are ignored
  let hideTimer = 0;
  let slotVisible = true;

  // Split into sentences so long text doesn't hit browser utterance limits.
  function splitSentences(text) {
    const out = [];
    const re = /[^.!?。！？।]+[.!?。！？।]*["'”’)\]]*\s*/g;
    let m;
    while ((m = re.exec(text))) {
      if (m[0].trim()) out.push({ start: m.index, text: m[0] });
    }
    return out.length ? out : [{ start: 0, text }];
  }

  function pickVoice(lang) {
    if (!synth) return null;
    const voices = synth.getVoices();
    const want = lang.toLowerCase();
    const base = want.split("-")[0];
    const norm = (v) => v.lang.replace("_", "-").toLowerCase();
    return (
      voices.find((v) => norm(v) === want && v.localService) ||
      voices.find((v) => norm(v) === want) ||
      voices.find((v) => norm(v).split("-")[0] === base && v.localService) ||
      voices.find((v) => norm(v).split("-")[0] === base) ||
      null
    );
  }

  function languageName(lang) {
    try {
      return new Intl.DisplayNames(["en"], { type: "language" }).of(lang.split("-")[0]);
    } catch {
      return lang;
    }
  }

  // ---------- Rendering ----------
  const escapeHTML = (s) => s.replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]);

  function renderText() {
    if (!reading) {
      textEl.textContent = IDLE_TEXT;
      return;
    }
    const { text, pos } = reading;
    const wordEnd = pos + (text.slice(pos).match(/^\S+/) || [""])[0].length;
    // Keep the current word in view: start a little before it, at a word boundary.
    let from = 0;
    if (pos > 70) {
      const space = text.indexOf(" ", pos - 70);
      from = space > -1 && space < pos ? space + 1 : pos;
    }
    const prefix = from > 0 ? "…" : "";
    textEl.innerHTML =
      prefix +
      escapeHTML(text.slice(from, pos)) +
      (wordEnd > pos ? `<mark>${escapeHTML(text.slice(pos, wordEnd))}</mark>` : "") +
      escapeHTML(text.slice(wordEnd));
  }

  function render() {
    player.classList.toggle("is-playing", state === "playing");
    btnPlay.setAttribute("aria-label", state === "playing" ? "Pause" : "Play");
    btnStop.disabled = state === "idle";
    const i = SPEEDS.indexOf(speed);
    btnSlower.disabled = i <= 0;
    btnFaster.disabled = i >= SPEEDS.length - 1;
    speedSelect.value = String(speed);
    $$(".speeds button").forEach((b) => b.setAttribute("aria-pressed", String(Number(b.dataset.speed) === speed)));
    progressEl.style.width = reading ? `${Math.min(100, (reading.pos / reading.text.length) * 100)}%` : "0%";
    $$(".voices tr").forEach((tr) => tr.classList.toggle("is-reading", !!reading && reading.row === tr));
    renderText();
    updateFloating();
  }

  // ---------- Speaking ----------
  function speakFrom(pos) {
    if (!synth || !reading) return;
    const token = ++epoch;
    synth.cancel();
    const voice = pickVoice(reading.lang);
    const startIndex = Math.max(0, reading.sentences.findLastIndex((s) => s.start <= pos));

    voiceEl.textContent = voice ? `${voice.name} · browser voice` : "Browser voice";
    langChip.hidden = false;
    langChip.lastElementChild.textContent = languageName(reading.lang);

    const speakSentence = (i, offset) => {
      if (token !== epoch) return;
      const sentence = reading.sentences[i];
      if (!sentence) return finish(token);
      const part = sentence.text.slice(offset);
      const u = new SpeechSynthesisUtterance(part);
      u.lang = reading.lang;
      if (voice) u.voice = voice;
      u.rate = speed;
      const base = sentence.start + offset;
      u.onboundary = (e) => {
        if (token !== epoch || e.name === "sentence") return;
        reading.pos = base + e.charIndex;
        render();
      };
      u.onend = () => {
        if (token !== epoch) return;
        reading.pos = sentence.start + sentence.text.length;
        speakSentence(i + 1, 0);
      };
      u.onerror = (e) => {
        if (token !== epoch || e.error === "interrupted" || e.error === "canceled") return;
        finish(token);
      };
      synth.speak(u);
    };

    const sentence = reading.sentences[startIndex];
    speakSentence(startIndex, Math.max(0, pos - sentence.start));
    state = "playing";
    clearTimeout(hideTimer);
    render();
  }

  function read(text, lang, row = null) {
    if (!synth) return;
    text = text.replace(/\s+/g, " ").trim();
    if (!text) return;
    reading = { text, lang: lang || "en-US", sentences: splitSentences(text), pos: 0, row };
    setDemoSound(false); // don't talk over the demo video
    speakFrom(0);
  }

  function finish(token) {
    if (token !== undefined && token !== epoch) return;
    epoch++;
    if (synth) synth.cancel();
    state = "idle";
    reading = null;
    voiceEl.textContent = "Screen text, naturally spoken.";
    langChip.hidden = true;
    render();
    // Like Audra's player, hide a few seconds after reading stops.
    clearTimeout(hideTimer);
    hideTimer = setTimeout(() => player.classList.remove("is-floating"), HIDE_DELAY_MS);
  }

  function togglePause() {
    if (!synth) return;
    if (state === "playing") {
      synth.pause();
      state = "paused";
    } else if (state === "paused") {
      synth.resume();
      state = "playing";
    }
    render();
  }

  function setSpeed(next) {
    if (!SPEEDS.includes(next) || next === speed) return;
    speed = next;
    // Utterance rate can't change mid-sentence, so restart from the current word.
    if (reading && state === "playing") speakFrom(reading.pos);
    else render();
  }

  // ---------- Selection ----------
  function selectionInfo() {
    const sel = window.getSelection();
    const text = sel ? sel.toString().trim() : "";
    if (!text) return null;
    const node = sel.anchorNode && (sel.anchorNode.nodeType === 1 ? sel.anchorNode : sel.anchorNode.parentElement);
    if (node && player.contains(node)) return null;
    const langEl = node && node.closest("[lang]");
    return { text, lang: (langEl && langEl.getAttribute("lang")) || "en-US" };
  }

  // Buttons can collapse the selection before "click", so remember it on pointerdown.
  let pendingSelection = null;
  btnPlay.addEventListener("pointerdown", () => { pendingSelection = selectionInfo(); });

  btnPlay.addEventListener("click", () => {
    const picked = pendingSelection || selectionInfo();
    pendingSelection = null;
    if (state !== "idle") return togglePause();
    if (picked) read(picked.text, picked.lang);
    else read(INTRO_SPOKEN, "en-US");
  });
  btnStop.addEventListener("click", () => finish());
  btnSlower.addEventListener("click", () => setSpeed(SPEEDS[SPEEDS.indexOf(speed) - 1]));
  btnFaster.addEventListener("click", () => setSpeed(SPEEDS[SPEEDS.indexOf(speed) + 1]));
  speedSelect.addEventListener("change", () => setSpeed(Number(speedSelect.value)));
  $$(".speeds button").forEach((b) => b.addEventListener("click", () => setSpeed(Number(b.dataset.speed))));

  // ⌥⇧S: read the selection; press again to stop. Option changes e.key on a Mac, so match e.code.
  document.addEventListener("keydown", (e) => {
    if (!(e.altKey && e.shiftKey && !e.metaKey && !e.ctrlKey && e.code === "KeyS")) return;
    e.preventDefault();
    if (state !== "idle") return finish();
    const picked = selectionInfo();
    if (picked) read(picked.text, picked.lang);
    else flashHint();
  });

  function flashHint() {
    textEl.textContent = "Select some text first, then press ⌥⇧S.";
    showFloatingIfNeeded(true);
    clearTimeout(hideTimer);
    hideTimer = setTimeout(() => {
      if (state === "idle") {
        renderText();
        player.classList.remove("is-floating");
      }
    }, HIDE_DELAY_MS);
  }

  $$(".voices tbody tr").forEach((tr) => {
    const sample = $(".sample", tr);
    $(".hear", tr).addEventListener("click", () => {
      if (reading && reading.row === tr) return finish();
      read(sample.textContent, sample.getAttribute("lang"), tr);
    });
  });

  // ---------- Floating player ----------
  function showFloatingIfNeeded(force = false) {
    const active = force || state !== "idle";
    if (active && !slotVisible) {
      clearTimeout(hideTimer);
      player.classList.add("is-floating");
    }
  }
  function updateFloating() {
    if (slotVisible) {
      player.classList.remove("is-floating");
    } else {
      showFloatingIfNeeded();
    }
  }
  if ("IntersectionObserver" in window) {
    new IntersectionObserver(([entry]) => {
      slotVisible = entry.isIntersecting;
      updateFloating();
    }, { threshold: 0.35 }).observe(slot);
  }
  // Stop the entrance animation from replaying when the player docks again.
  player.addEventListener("animationend", (e) => {
    if (e.animationName === "arrive") player.classList.add("is-settled");
  });

  // ---------- Unsupported browsers ----------
  if (!synth) {
    textEl.textContent = "This browser can't read aloud. Audra on your Mac can.";
    [btnPlay, btnSlower, btnFaster, speedSelect].forEach((el) => (el.disabled = true));
    $$(".hear").forEach((b) => (b.disabled = true));
  } else {
    // Voices load asynchronously in Chrome.
    synth.getVoices();
    window.addEventListener("beforeunload", () => synth.cancel());
  }

  // ---------- Demo video ----------
  // Plays muted and looped while on screen, like a GIF; sound is opt-in.
  const video = $("#demo-video");
  const btnSound = $("#demo-sound");
  const btnToggle = $("#demo-toggle");
  const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  let userPaused = reduceMotion;
  let videoVisible = false;

  function renderDemo() {
    btnToggle.textContent = video.paused ? "Play" : "Pause";
    btnSound.setAttribute("aria-pressed", String(!video.muted));
    btnSound.lastElementChild.textContent = video.muted ? "Turn sound on" : "Turn sound off";
    btnSound.classList.toggle("is-on", !video.muted);
  }

  function setDemoSound(on) {
    if (!video || video.muted === !on) return;
    video.muted = !on;
    renderDemo();
  }

  function playDemo() {
    const p = video.play();
    if (p) p.catch(() => {});
  }

  if (video) {
    btnSound.addEventListener("click", () => {
      const on = video.muted;
      if (on) {
        finish(); // stop the page's own reader
        video.currentTime = 0; // hear it from the start
        userPaused = false;
        playDemo();
      }
      setDemoSound(on);
    });
    btnToggle.addEventListener("click", () => {
      userPaused = !video.paused;
      if (userPaused) video.pause();
      else playDemo();
    });
    video.addEventListener("play", renderDemo);
    video.addEventListener("pause", renderDemo);
    video.addEventListener("volumechange", renderDemo);

    if ("IntersectionObserver" in window) {
      new IntersectionObserver(([entry]) => {
        videoVisible = entry.isIntersecting;
        if (!videoVisible) video.pause();
        else if (!userPaused) playDemo();
      }, { threshold: 0.4 }).observe(video);
    } else if (!userPaused) {
      playDemo();
    }
    renderDemo();
  }

  // ---------- Install: copy ----------
  $$(".copy").forEach((btn) => {
    btn.addEventListener("click", async () => {
      const code = document.getElementById(btn.dataset.copy).cloneNode(true);
      $$(".prompt", code).forEach((p) => p.remove());
      try {
        await navigator.clipboard.writeText(code.textContent.trim());
        btn.textContent = "Copied";
        btn.classList.add("is-done");
      } catch {
        btn.textContent = "Press ⌘C";
        const range = document.createRange();
        range.selectNodeContents(document.getElementById(btn.dataset.copy));
        const sel = window.getSelection();
        sel.removeAllRanges();
        sel.addRange(range);
      }
      setTimeout(() => {
        btn.textContent = "Copy";
        btn.classList.remove("is-done");
      }, 2000);
    });
  });

  // ---------- Latest release ----------
  fetch("https://api.github.com/repos/buemura/audra/releases/latest", { headers: { Accept: "application/vnd.github+json" } })
    .then((r) => (r.ok ? r.json() : Promise.reject(r.status)))
    .then((release) => {
      const version = String(release.tag_name || "").replace(/^v/, "");
      if (version) $$("[data-version]").forEach((el) => (el.textContent = `Version ${version}`));
    })
    .catch(() => {});

  render();
})();
