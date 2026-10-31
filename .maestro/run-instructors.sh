#!/usr/bin/env bash
# Instructors flows (build with --dart-define=INSTRUCTORS=true) against the
# LOCAL emulators. Reseeds first, so chats, bookings and reviews start the same
# every run, and switches the seed students to English (the seed sets 'ru').
#   .maestro/run-instructors.sh [flow.yaml ...]   (default: every instructors/*.yaml)
set -euo pipefail
MAESTRO="${MAESTRO:-$HOME/.maestro/maestro/bin/maestro}"
FS="http://127.0.0.1:8080/v1/projects/licenseprepapp/databases/(default)/documents"
cd "$(dirname "$0")/.."

# The seed's recursiveDelete of a chat the flows wrote to fails on the emulator
# ("CANCELLED: call already cancelled"), so empty the seed chats first.
for conv in seed-student-paid_seed-instr-01 seed-student-paid_seed-instr-03 seed-student-paid_seed-instr-04; do
  for doc in $(curl -s -H 'Authorization: Bearer owner' "$FS/conversations/$conv/messages?pageSize=300"       | grep -o '"name": *"[^"]*"' | sed 's/.*documents\///; s/"$//'); do
    curl -s -X DELETE -H 'Authorization: Bearer owner' "$FS/$doc" > /dev/null
  done
  curl -s -X DELETE -H 'Authorization: Bearer owner' "$FS/conversations/$conv" > /dev/null
done

FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 \
  GCLOUD_PROJECT=licenseprepapp node scripts/local/seed-instructors.js > /dev/null
for uid in seed-student-paid seed-student-trial seed-student-md; do
  curl -s -X PATCH -H 'Authorization: Bearer owner' -H 'Content-Type: application/json' \
    "$FS/users/$uid?updateMask.fieldPaths=language" \
    -d '{"fields":{"language":{"stringValue":"en"}}}' > /dev/null
done

cd .maestro
[ $# -gt 0 ] || set -- instructors/*.yaml
# Every seed account shares the seed script's SEED_PASSWORD.
for flow in "$@"; do
  "$MAESTRO" test -e PASSWORD="seed-instructor-2026" "${flow#.maestro/}"
done
