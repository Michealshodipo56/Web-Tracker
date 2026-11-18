#!/usr/bin/env bash
# End-to-end API smoke test on the deployed VM. Prints no credentials or values.
set -Eeuo pipefail
umask 077
[[ $EUID -eq 0 ]] || { echo 'Run with sudo.' >&2; exit 1; }
set -a
. /etc/web-tracker/app.env
set +a
cookie=$(mktemp)
trap 'rm -f "$cookie"' EXIT
json_value() { python3 -c 'import json,sys; print(json.load(sys.stdin)[sys.argv[1]])' "$1"; }
origin_header="Origin: $APP_ORIGIN"

printf '{"password":"%s"}' "$ADMIN_PASSWORD" | curl -fsS -c "$cookie" -H "$origin_header" -H 'Content-Type: application/json' --data-binary @- "$APP_ORIGIN/api/login" | grep -q '"ok":true'
curl -fsS -b "$cookie" "$APP_ORIGIN/api/session" | grep -q '"ok":true'
projects=$(curl -fsS -b "$cookie" "$APP_ORIGIN/api/projects")
project_id=$(printf '%s' "$projects" | python3 -c 'import json,sys; print(next((p["id"] for p in json.load(sys.stdin) if p["repo"].lower()=="michealshodipo56/web-tracker"), ""))')
if [[ -z "$project_id" ]]; then
  project_id=$(printf '%s' '{"repo":"https://github.com/Michealshodipo56/Web-Tracker"}' | curl -fsS -b "$cookie" -H "$origin_header" -H 'Content-Type: application/json' --data-binary @- "$APP_ORIGIN/api/projects" | json_value id)
fi
milestones=$(curl -fsS -b "$cookie" -H "$origin_header" -X POST "$APP_ORIGIN/api/projects/$project_id/sync")
printf '%s' "$milestones" | python3 -c 'import json,sys; assert len(json.load(sys.stdin)["milestones"]) >= 4'

name="smoke-$(openssl rand -hex 8)"
value=$(openssl rand -hex 32)
secret_id=$(printf '{"name":"%s","value":"%s"}' "$name" "$value" | curl -fsS -b "$cookie" -H "$origin_header" -H 'Content-Type: application/json' --data-binary @- "$APP_ORIGIN/api/projects/$project_id/secrets" | json_value id)
listing=$(curl -fsS -b "$cookie" "$APP_ORIGIN/api/projects/$project_id/secrets")
printf '%s' "$listing" | python3 -c 'import json,sys; assert all("value" not in row and "ciphertext" not in row for row in json.load(sys.stdin))'
[[ "$listing" != *"$value"* ]]
first_reveal=$(curl -fsS -b "$cookie" -H "$origin_header" -X POST "$APP_ORIGIN/api/projects/$project_id/secrets/$secret_id/reveal" | json_value value)
[[ "$first_reveal" == "$value" ]]
stored_ciphertext=$(runuser -u postgres -- psql -d webtracker -tAc "SELECT ciphertext FROM secrets WHERE id='$secret_id'")
[[ -n "$stored_ciphertext" && "$stored_ciphertext" != *"$value"* ]]

systemctl restart web-tracker
for attempt in {1..15}; do
  if curl -fsS -b "$cookie" "$APP_ORIGIN/api/session" 2>/dev/null | grep -q '"ok":true'; then break; fi
  sleep 2
done
second_reveal=$(curl -fsS -b "$cookie" -H "$origin_header" -X POST "$APP_ORIGIN/api/projects/$project_id/secrets/$secret_id/reveal" | json_value value)
[[ "$second_reveal" == "$value" ]]
curl -fsS -b "$cookie" -H "$origin_header" -X DELETE "$APP_ORIGIN/api/projects/$project_id/secrets/$secret_id" | grep -q '"ok":true'
[[ "$(curl -s -o /dev/null -w '%{http_code}' -b "$cookie" -H "$origin_header" -X POST "$APP_ORIGIN/api/projects/$project_id/secrets/$secret_id/reveal")" == 404 ]]

systemctl start web-tracker-backup.service
bash /opt/web-tracker/current/ops/oracle-verify-backup.sh
echo 'Passed: HTTPS, login, GitHub import, milestone sync, vault encryption/reveal/delete, restart persistence, backup restore.'
echo 'Screenshot capture has not passed; it remains disabled pending worker isolation.'
