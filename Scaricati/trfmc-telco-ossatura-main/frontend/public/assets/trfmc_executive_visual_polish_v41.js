(function(){
  const VERSION = "TRFMC_V0_41A_EXECUTIVE_VISUAL_POLISH";

  function ready(fn){
    if(document.readyState === "loading") document.addEventListener("DOMContentLoaded", fn);
    else fn();
  }

  function ensureWatermark(){
    if(document.querySelector(".v41-watermark")) return;
    const w = document.createElement("div");
    w.className = "v41-watermark";
    w.textContent = "TRFMC v0.41A · Cinematic Mission UI";
    document.body.appendChild(w);
  }

  function injectDynamicReadiness(){
    const core = document.querySelector(".v41-mission-core");
    if(!core) return;

    const stamp = document.createElement("div");
    stamp.style.position = "absolute";
    stamp.style.left = "18px";
    stamp.style.bottom = "14px";
    stamp.style.color = "rgba(88,214,249,.45)";
    stamp.style.fontSize = "10px";
    stamp.style.letterSpacing = "1.4px";
    stamp.textContent = VERSION + " · LOCALHOST_ONLY";
    core.appendChild(stamp);
  }

  function animateSignalBoard(){
    const board = document.querySelector(".v41-signal-board");
    if(!board) return;
    let tick = 0;
    setInterval(() => {
      tick++;
      board.style.boxShadow = tick % 2
        ? "0 0 42px rgba(88,214,249,.12), inset 0 0 36px rgba(88,214,249,.045)"
        : "0 0 42px rgba(63,185,80,.10), inset 0 0 36px rgba(88,214,249,.045)";
    }, 1800);
  }

  ready(function(){
    ensureWatermark();
    injectDynamicReadiness();
    animateSignalBoard();
  });
})();
