// CI-only smoke test. scripts/ios-smoke.sh injects it into the simulator build's
// public/index.html; it is never part of the signed app. The app's own WebKit, at origin
// capacitor://localhost, reads production, which is the CORS check curl cannot make from
// GitHub's runners (Cloudflare challenges curl there). It ends with one line,
// "[smoke] PASS" or "[smoke] FAIL: <why>", which the script waits for.
(function () {
  const say = (...a) => console.log("[smoke]", ...a);
  const errors = [];
  const fetched = [];
  const origFetch = window.fetch.bind(window);
  window.fetch = async (...args) => {
    const url = String((args[0] && args[0].url) || args[0]);
    try {
      const r = await origFetch(...args);
      fetched.push([r.status, url]);
      return r;
    } catch (e) {
      errors.push(`fetch ${url}: ${e}`);
      throw e;
    }
  };
  window.addEventListener("error", (e) => errors.push(`error ${e.message} ${e.filename}:${e.lineno}`));
  window.addEventListener("unhandledrejection", (e) => errors.push(`unhandled rejection ${e.reason}`));
  const text = () => (document.body.innerText || "").replace(/\s+/g, " ");
  const waitFor = (what, pred, ms) =>
    new Promise((resolve, reject) => {
      const t0 = Date.now();
      const tick = () => {
        let v;
        try { v = pred(); } catch (e) { v = null; }
        if (v) return resolve(v);
        if (Date.now() - t0 > ms) return reject(new Error(`timed out after ${ms} ms waiting for ${what}`));
        setTimeout(tick, 250);
      };
      tick();
    });

  async function run() {
    say("origin", location.origin);
    const build = await (await origFetch("/BUILD.json")).json();
    say("web", build.commit, "api", build.api_origin);
    // 1. The app origin reads the report list (a CORS failure throws here).
    const r = await fetch(`${build.api_origin}/api/reports`, { headers: { Accept: "application/json" } });
    const list = await r.json();
    if (r.status !== 200 || !Array.isArray(list) || !list.length) throw new Error(`/api/reports gave ${r.status} with ${Array.isArray(list) ? list.length : "no"} rows`);
    say("reports", list.length);
    // 2. Home shows them; open the first one as a reader would.
    const link = await waitFor("a report row on home", () => document.querySelector('a.rep[href^="/reports/"]'), 30000);
    const href = link.getAttribute("href");
    say("open", href);
    link.click();
    // 3. The report's summary renders (P02, .pg-summary), not an offline or status page.
    const page = await waitFor(`the report summary at ${href}`, () => {
      const el = location.pathname === href && document.querySelector(".pg-summary, .pg-status");
      return el && (el.innerText || "").replace(/\s+/g, " ").length > 200 ? el : null;
    }, 30000);
    const pageText = (page.innerText || "").replace(/\s+/g, " ");
    if (!page.classList.contains("pg-summary")) throw new Error(`the report shows a status page instead of its summary: ${pageText.slice(0, 160)}`);
    if (/沒有網路連線/.test(pageText)) throw new Error(`the report shows the offline state: ${pageText.slice(0, 160)}`);
    say("report", location.pathname, pageText.slice(0, 100));
    await new Promise((res) => setTimeout(res, 1500)); // let the page's own fetches settle
    // A report without 目標價怎麼算 answers 404 at its walkthrough, and the summary then
    // draws no chapter row (research repo 68c3d97); every other 4xx or 5xx still fails.
    const noChapter = ([status, url]) =>
      status === 404 && /\/api\/reports\/[^/]+\/versions\/[^/]+\/walkthrough$/.test(new URL(url).pathname);
    const bad = fetched.filter((f) => f[0] >= 400 && !noChapter(f));
    if (bad.length) throw new Error(`HTTP errors: ${bad.map(([s, u]) => `${s} ${u}`).join(", ")}`);
    if (errors.length) throw new Error(errors.join("; "));
    say("fetches", fetched.map(([s, u]) => `${s} ${u.replace(build.api_origin, "")}`).join(", "));
  }

  window.addEventListener("load", () => {
    run().then(
      () => console.log("[smoke] PASS"),
      (e) => console.log(`[smoke] FAIL: ${e && e.message ? e.message : e}${errors.length ? ` | errors: ${errors.join("; ")}` : ""}`),
    );
  });
})();
