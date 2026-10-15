// CI-only probe, injected into the simulator build's public/index.html; never shipped.
// Walks home -> 早報 list -> first issue -> its appendix by clicking the same links a
// reader taps, and logs every fetch, error and the visible text along the way.
(function () {
  const log = (...a) => console.log("[probe]", ...a);
  const text = () => ((document.querySelector("main") || document.body).innerText || "").replace(/\s+/g, " ").slice(0, 240);
  const origFetch = window.fetch.bind(window);
  window.fetch = async (...args) => {
    const url = String((args[0] && args[0].url) || args[0]);
    try {
      const r = await origFetch(...args);
      log("fetch", r.status, url, "acao=" + r.headers.get("access-control-allow-origin"));
      return r;
    } catch (e) {
      console.error("[probe] fetch FAILED", url, String(e));
      throw e;
    }
  };
  window.addEventListener("error", (e) => console.error("[probe] error", e.message, e.filename + ":" + e.lineno));
  window.addEventListener("unhandledrejection", (e) => console.error("[probe] unhandled rejection", String(e.reason && (e.reason.stack || e.reason))));
  const click = (sel, what) => {
    const a = document.querySelector(sel);
    log("click", what, a ? a.getAttribute("href") : "NOT FOUND (" + sel + ")");
    if (a) a.click();
    return !!a;
  };
  const steps = [
    [7000, () => { log("step1 at", location.href, "|", text()); click('a[href="/briefs"]', "home brief entry"); }],
    [15000, () => { log("step2 at", location.href, "rows", document.querySelectorAll(".pg-brief-list a.iss").length, "|", text()); click(".pg-brief-list a.iss", "first issue row"); }],
    [23000, () => { log("step3 at", location.href, "|", text()); click('a[href$="/appendix"]', "appendix"); }],
    [31000, () => { log("step4 at", location.href, "|", text()); }],
  ];
  for (const [t, f] of steps) setTimeout(() => { try { f(); } catch (e) { console.error("[probe] step failed", String(e)); } }, t);
  log("injected", navigator.userAgent);
})();
