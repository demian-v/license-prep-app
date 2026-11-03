#!/usr/bin/env bash
# Runs the sign-up flow end to end against the LOCAL emulators.
#   EMU_LOG=<file with `firebase emulators:start` output> TRACKING="Allow"|"Don't allow" \
#     .maestro/run-signup.sh [then more flows, e.g. .maestro/trial.yaml ...]
# The code is stored hashed, so it is read from the functions emulator's
# LoggingEmailSender output. Clears trialDevices first (one trial per phone).
# On the iOS Simulator the server refuses a trial (isPhysicalDevice is false),
# so grant-local-trial.js writes one instead: that run shows the trial on
# screen, not the server granting it.
set -euo pipefail
: "${EMU_LOG:?set EMU_LOG to the emulator log file}"
MAESTRO="${MAESTRO:-$HOME/.maestro/maestro/bin/maestro}"
FS="http://127.0.0.1:8080/v1/projects/licenseprepapp/databases/(default)/documents"
DONT_ALLOW="Don't allow"
TRACKING="${TRACKING:-$DONT_ALLOW}"
IOS_SIM=""
if command -v xcrun > /dev/null && xcrun simctl list devices booted | grep -q Booted; then
  IOS_SIM=1
  [ "$TRACKING" != "$DONT_ALLOW" ] || TRACKING="Ask App Not to Track"
fi
EMAIL="maestro-$(date +%s)@example.com"
cd "$(dirname "$0")"

for name in $(curl -s -H 'Authorization: Bearer owner' "$FS/trialDevices?pageSize=300" \
    | grep -o '"name": *"[^"]*"' | sed 's/.*documents\///; s/"$//'); do
  curl -s -X DELETE -H 'Authorization: Bearer owner' "$FS/$name" > /dev/null
done

"$MAESTRO" test -e NAME="Maestro Student" -e EMAIL="$EMAIL" -e PASSWORD="maestro-pass-1" subflows/signup_start.yaml

CODE=""
for _ in $(seq 1 30); do
  CODE=$(grep -a -A1 "to: *$EMAIL" "$EMU_LOG" | grep -a -o 'verification code: [0-9]\{6\}' | tail -1 | grep -o '[0-9]\{6\}' || true)
  [ -n "$CODE" ] && break
  sleep 1
done
[ -n "$CODE" ] || { echo "No code for $EMAIL in $EMU_LOG"; exit 1; }
echo "Code for $EMAIL: $CODE"

if [ -n "$IOS_SIM" ]; then
  FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 GCLOUD_PROJECT=licenseprepapp \
    node ../scripts/local/grant-local-trial.js "$EMAIL"
fi

"$MAESTRO" test -e CODE="$CODE" -e TRACKING="$TRACKING" subflows/signup_finish.yaml
for flow in "$@"; do "$MAESTRO" test "$(basename "$flow")"; done
