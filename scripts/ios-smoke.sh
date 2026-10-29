#!/usr/bin/env bash
# CI only (macOS): run .github/smoke/smoke.js inside the app on an iPhone simulator and fail
# unless it reports PASS. The script goes into a copy of a simulator build's
# public/index.html; the signed app never contains it.
#
#   scripts/ios-smoke.sh <out dir> [<App.app>]   # builds a Debug simulator app if none is given
#
# The app's own WebKit, at origin capacitor://localhost, reads production and opens a report:
# the CORS check that curl cannot make from GitHub's runners (Cloudflare challenges curl).
set -euo pipefail

out="${1:?usage: scripts/ios-smoke.sh <out dir> [<App.app>]}"
app="${2:-}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bundle_id="com.oraclelee.invest"
mkdir -p "${out}"
work="$(mktemp -d)"

if [ -z "${app}" ]; then
    (cd "${root}" && npx cap sync ios >/dev/null)
    (cd "${root}/ios/App" && xcodebuild -project App.xcodeproj -scheme App -configuration Debug \
        -sdk iphonesimulator -destination "generic/platform=iOS Simulator" \
        -derivedDataPath "${work}/dd" CODE_SIGNING_ALLOWED=NO -quiet build)
    app="${work}/dd/Build/Products/Debug-iphonesimulator/App.app"
fi
cp -R "${app}" "${work}/App.app"
node -e '
const fs = require("fs");
const [page, js] = process.argv.slice(1);
const html = fs.readFileSync(page, "utf8");
if (!html.includes("<head>")) throw new Error(`no <head> in ${page}`);
fs.writeFileSync(page, html.replace("<head>", `<head>\n<script>${fs.readFileSync(js, "utf8")}</script>`));
' "${work}/App.app/public/index.html" "${root}/.github/smoke/smoke.js"

# The newest iPhone Pro Max the runner has (the owner's phone class), else the newest iPhone.
udid="$(xcrun simctl list devices available -j | node -e '
const d = JSON.parse(require("fs").readFileSync(0, "utf8")).devices;
const phones = Object.entries(d).filter(([rt]) => rt.includes("iOS")).flatMap(([, l]) => l)
  .filter((x) => x.name.startsWith("iPhone"));
const pick = phones.filter((x) => x.name.includes("Pro Max")).at(-1) || phones.at(-1);
console.log(pick.udid);')"
xcrun simctl list devices | grep "${udid}" | sed 's/^ *//' > "${out}/device.txt"
xcrun simctl boot "${udid}" 2>/dev/null || true
xcrun simctl bootstatus "${udid}" -b >/dev/null
xcrun simctl uninstall "${udid}" "${bundle_id}" 2>/dev/null || true
xcrun simctl install "${udid}" "${work}/App.app"
launch() {
    xcrun simctl launch --console-pty --terminate-running-process "${udid}" "${bundle_id}" \
        > "${out}/console.log" 2>&1 &
    launcher=$!
}
# The app prints Capacitor's own line as soon as it starts, before any page loads. A slow simulator
# has launched the app and never had it print anything (2026-10-29, twice): the page was never
# reached, so that launch says nothing about the page. Such a launch is retried once.
started() { grep -a -q -E 'Loading app at capacitor://|\[smoke\]' "${out}/console.log"; }
launch
for _ in $(seq 1 60); do
    started && break
    sleep 1
done
if ! started; then
    echo "the app printed nothing within 60 s of launch; launching it again"
    cp "${out}/console.log" "${out}/console-first-launch.log"
    xcrun simctl io "${udid}" screenshot "${out}/first-launch.png" >/dev/null 2>&1 || true
    xcrun simctl terminate "${udid}" "${bundle_id}" 2>/dev/null || true
    kill "${launcher}" 2>/dev/null || true
    launch
fi

verdict=""
for _ in $(seq 1 120); do
    verdict="$(grep -a -o -E '\[smoke\] (PASS|FAIL.*)' "${out}/console.log" | head -n 1 || true)"
    [ -n "${verdict}" ] && break
    sleep 1
done
xcrun simctl io "${udid}" screenshot "${out}/smoke.png" >/dev/null 2>&1 || true
xcrun simctl terminate "${udid}" "${bundle_id}" 2>/dev/null || true
kill "${launcher}" 2>/dev/null || true
grep -a '\[smoke\]' "${out}/console.log" | sed 's/^.*\[smoke\]/[smoke]/' > "${out}/smoke.txt" || true
cat "${out}/smoke.txt"

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
    {
        echo "### Simulator smoke ($(cat "${out}/device.txt"))"
        sed 's/^/    /' "${out}/smoke.txt"
    } >> "${GITHUB_STEP_SUMMARY}"
fi
case "${verdict}" in
    "[smoke] PASS") exit 0 ;;
    "") if started; then
            echo "::error::the page gave no verdict within 120 s; see ${out}/console.log"
        else
            echo "::error::the app did not start on the simulator (no output after two launches); see ${out}/console.log"
        fi
        exit 1 ;;
    *) echo "::error::${verdict}"; exit 1 ;;
esac
