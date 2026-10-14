#!/usr/bin/env bash
# Store the App Store signing material as GitHub secrets of this repository.
# The certificate and the App Store Connect API key are connect4's (the team's), restored
# from the owner's backup into ~/.config/invest-mobile/ios; only the provisioning profile
# is this app's own. docs/apple-setup.md walks the account holder through Apple's websites.
#
# Usage:
#   scripts/ios-signing.sh check <profile.mobileprovision>
#       check the profile's name, bundle id and team, and that it carries the restored certificate
#   scripts/ios-signing.sh secrets <profile.mobileprovision> <team id> <app store connect app id>
#       check, move the profile next to the rest and store everything as GitHub secrets
#
# Expected in the directory: distribution.p12, p12-password.txt, AuthKey_<key id>.p8 and
# asc.json ({"key_id", "issuer_id"}). Nothing secret is printed; secrets reach GitHub
# through stdin only. No Mac is needed.
set -euo pipefail

DIR="${HOME}/.config/invest-mobile/ios"
REPO="${INVEST_APP_REPO:-EdwardLeeee/invest-app}"
BUNDLE_ID="com.oraclelee.invest"
PROFILE_NAME="Invest App Store"

usage() {
    sed -n '7,12p' "$0" >&2
    exit 2
}

need() {
    [ -f "${DIR}/$1" ] || { echo "missing ${DIR}/$1; restore it from the backup first" >&2; exit 1; }
}

# The certificate inside the .p12, as DER. The .p12 was written with -legacy (RC2), which
# OpenSSL 3 reads only with its legacy provider, so try that second.
p12_certificate() {
    local pass="file:${DIR}/p12-password.txt"
    openssl pkcs12 -in "${DIR}/distribution.p12" -passin "${pass}" -nokeys -clcerts 2>/dev/null \
        || openssl pkcs12 -legacy -in "${DIR}/distribution.p12" -passin "${pass}" -nokeys -clcerts
}

check_profile() {
    local profile="$1"
    [ -f "${profile}" ] || usage
    need distribution.p12
    need p12-password.txt
    local cert_sha
    cert_sha="$(p12_certificate | openssl x509 -outform DER | sha256sum | cut -d' ' -f1)"
    openssl smime -inform der -verify -noverify -in "${profile}" 2>/dev/null \
        | python3 -I -c '
import hashlib, plistlib, sys
name, bundle_id, cert_sha = sys.argv[1:]
p = plistlib.loads(sys.stdin.buffer.read())
team = p["TeamIdentifier"][0]
actual_name = p["Name"]
app_identifier = p["Entitlements"]["application-identifier"]
expires = p["ExpirationDate"]
certificates = {hashlib.sha256(c).hexdigest() for c in p["DeveloperCertificates"]}
errors = []
if actual_name != name:
    errors.append(f"the profile is named {actual_name!r}; the Xcode project expects {name!r}")
if app_identifier != f"{team}.{bundle_id}":
    errors.append(f"the profile is for {app_identifier}, not {team}.{bundle_id}")
if p["Entitlements"].get("get-task-allow"):
    errors.append("this is a development profile; make an App Store Connect distribution profile")
if cert_sha not in certificates:
    errors.append("the profile does not carry the restored distribution certificate; tick that one when making it")
for e in errors:
    print(e, file=sys.stderr)
if errors:
    sys.exit(1)
print(f"profile ok: {actual_name}, team {team}, expires {expires:%Y-%m-%d}")
' "${PROFILE_NAME}" "${BUNDLE_ID}" "${cert_sha}"
}

case "${1:-}" in
    check)
        [ "$#" -eq 2 ] || usage
        check_profile "$2"
        ;;
    secrets)
        [ "$#" -eq 4 ] || usage
        profile="$2" team_id="$3" app_id="$4"
        [[ "${team_id}" =~ ^[A-Z0-9]{10}$ ]] || { echo "a Team ID is 10 letters and digits" >&2; exit 1; }
        [[ "${app_id}" =~ ^[0-9]+$ ]] || { echo "the app's Apple ID is a number" >&2; exit 1; }
        need asc.json
        check_profile "${profile}"
        key_id="$(python3 -I -c 'import json, sys; print(json.load(open(sys.argv[1]))["key_id"])' "${DIR}/asc.json")"
        issuer_id="$(python3 -I -c 'import json, sys; print(json.load(open(sys.argv[1]))["issuer_id"])' "${DIR}/asc.json")"
        need "AuthKey_${key_id}.p8"

        umask 077
        # Move the download here so it does not linger in Downloads; mv keeps the browser's
        # mode (often 0644), and the profile must be private like the rest.
        [ "${profile}" -ef "${DIR}/app-store.mobileprovision" ] || mv "${profile}" "${DIR}/app-store.mobileprovision"
        chmod 600 "${DIR}/app-store.mobileprovision"

        base64 -w0 "${DIR}/distribution.p12" | gh secret set IOS_DIST_CERT_P12_BASE64 --repo "${REPO}"
        gh secret set IOS_DIST_CERT_P12_PASSWORD --repo "${REPO}" < "${DIR}/p12-password.txt"
        base64 -w0 "${DIR}/app-store.mobileprovision" | gh secret set IOS_PROFILE_BASE64 --repo "${REPO}"
        base64 -w0 "${DIR}/AuthKey_${key_id}.p8" | gh secret set ASC_API_KEY_P8_BASE64 --repo "${REPO}"
        printf '%s' "${key_id}" | gh secret set ASC_API_KEY_ID --repo "${REPO}"
        printf '%s' "${issuer_id}" | gh secret set ASC_API_ISSUER_ID --repo "${REPO}"
        printf '%s' "${team_id}" | gh secret set APPLE_TEAM_ID --repo "${REPO}"
        # Not a secret: the refresh workflow reads it to look up the latest build.
        gh variable set ASC_APP_ID --repo "${REPO}" --body "${app_id}"
        echo "iOS secrets and ASC_APP_ID stored in ${REPO}"
        ;;
    *)
        usage
        ;;
esac
