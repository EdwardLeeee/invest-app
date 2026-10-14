#!/usr/bin/env bash
# Build the research room's frontend for the app and copy it into web/.
#
#   scripts/import-web.sh [<ref>]     # default: origin/main of the research repository
#
# The research repository is private and stays on the developer machine; only its built
# frontend comes here, the same files the public site serves. The build points every API
# call at the production site (VITE_API_ORIGIN), whose backend allows this app's origin.
# web/BUILD.json records which commit was built. Commit the result and run Mobile release.
set -euo pipefail

INVEST_REPO="${INVEST_REPO:-${HOME}/Desktop/invest}"
API_ORIGIN="https://invest.oraclelee.com"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ref="${1:-origin/main}"

git -C "${INVEST_REPO}" fetch --quiet origin
commit="$(git -C "${INVEST_REPO}" rev-parse --verify --quiet "${ref}^{commit}")" || {
    echo "unknown ref in ${INVEST_REPO}: ${ref}" >&2
    exit 1
}
# Only pushed commits: the app must be reproducible from what GitHub holds.
if ! git -C "${INVEST_REPO}" merge-base --is-ancestor "${commit}" origin/main; then
    echo "${commit} is not on the research repository's origin/main; push it first" >&2
    exit 1
fi

work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT
# A clean export of the commit, not the working tree: frontend/ plus the published
# reports that the type check (tsc -b) reads through the tests.
git -C "${INVEST_REPO}" archive "${commit}" frontend reports/published | tar -x -C "${work}"
(
    cd "${work}/frontend"
    npm ci --no-audit --no-fund --loglevel=error
    VITE_API_ORIGIN="${API_ORIGIN}" npm run build
)
dist="${work}/frontend/dist"

# The checks that make the bundle safe to ship and to publish here.
fail() { echo "import-web: $1" >&2; exit 1; }
grep -rqF "${API_ORIGIN}" "${dist}/assets" || fail "the build does not call ${API_ORIGIN}; is VITE_API_ORIGIN supported at ${commit}?"
[ -z "$(find "${dist}" -name '*.map' -print -quit)" ] || fail "the build has source maps"
# Reports reach the app over the API only; a report bundled into the build would go stale.
python3 -I - "${work}/reports/published" "${dist}" <<'EOF' || fail "a published report is bundled into the build"
import json, pathlib, sys
reports, dist = map(pathlib.Path, sys.argv[1:])
# Probe each report with text only a report holds: the company's name, and the opening of
# a written summary (the macro reports have no company).
probes = set()
for path in reports.glob("*/*/report.json"):
    report = json.loads(path.read_text())
    security = report.get("security")
    if isinstance(security, dict) and isinstance(security.get("name"), str):
        probes.add(security["name"])
    if isinstance(report.get("summary"), str) and len(report["summary"]) >= 20:
        probes.add(report["summary"][:40])
if not probes:
    sys.exit("no probes: the report layout changed; update this check")
text = "\n".join(p.read_text(errors="ignore") for p in dist.rglob("*") if p.is_file())
found = sorted(n for n in probes if n in text)
if found:
    print("bundled report text: " + ", ".join(found[:5]), file=sys.stderr)
    sys.exit(1)
EOF

rm -rf "${ROOT}/web"
cp -R "${dist}" "${ROOT}/web"
node -e '
const [commit, ref, origin, version, out] = process.argv.slice(1);
const build = { source: "EdwardLeeee/invest (private)", commit, ref, frontend_version: version,
  api_origin: origin, built_at: new Date().toISOString().replace(/\.\d+Z$/, "Z"), node: process.version };
require("fs").writeFileSync(out, JSON.stringify(build, null, 2) + "\n");
' "${commit}" "${ref}" "${API_ORIGIN}" \
    "$(node -p "require('${work}/frontend/package.json').version")" "${ROOT}/web/BUILD.json"
echo "web/ now holds the frontend of ${commit:0:12} (${ref}); review, commit, then run Mobile release"
