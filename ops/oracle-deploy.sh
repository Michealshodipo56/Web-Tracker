#!/usr/bin/env bash
# First-install / update helper for the existing Ubuntu 24.04 Oracle VM.
# Run as root after reviewing. No user-supplied secrets are accepted as arguments.
set -Eeuo pipefail
umask 077

repo='https://github.com/Michealshodipo56/Web-Tracker.git'
domain='web-tracker.145-241-223-113.nip.io'
public_ip='145.241.223.113'
port='4117'
base='/opt/web-tracker'
env_file='/etc/web-tracker/app.env'
caddy_file='/etc/caddy/Caddyfile'
stage=''
caddy_backup=''
caddy_changed=0

rollback_on_error() {
  local status=$?
  trap - ERR
  if [[ "$caddy_changed" == 1 && -f "$caddy_backup" ]]; then
    cp -p "$caddy_backup" "$caddy_file"
    systemctl reload caddy || true
    echo 'Caddy configuration restored after deployment error.' >&2
  fi
  [[ -z "$stage" || ! -d "$stage" ]] || rm -rf "$stage"
  echo "Deployment stopped (exit $status). Existing backend services were not changed." >&2
  exit "$status"
}
trap rollback_on_error ERR

[[ $EUID -eq 0 ]] || { echo 'Run as root with sudo.' >&2; exit 1; }
[[ -f "$caddy_file" ]] || { echo 'Caddyfile missing.' >&2; exit 1; }
[[ -f /etc/os-release ]] || exit 1
. /etc/os-release
[[ "$ID" == ubuntu && "$VERSION_ID" == '24.04' ]] || { echo 'Expected Ubuntu 24.04.' >&2; exit 1; }
for program in git npm node openssl caddy curl; do
  command -v "$program" >/dev/null || { echo "Missing required program: $program" >&2; exit 1; }
done
[[ "$(getent ahostsv4 "$domain" | awk 'NR==1 {print $1}')" == "$public_ip" ]] || { echo 'Hostname DNS does not point to this VM.' >&2; exit 1; }
if grep -Fq "$domain" "$caddy_file" && ! grep -Fq "$domain {" "$caddy_file"; then
  echo 'Hostname appears in an existing Caddy route; inspect it manually.' >&2
  exit 1
fi
if ss -lnt "( sport = :$port )" | grep -q LISTEN && ! systemctl is-active --quiet web-tracker; then
  echo "Port $port is in use by another service." >&2
  exit 1
fi

install -d -m 0755 "$base" "$base/releases"
stage=$(mktemp -d "$base/releases/.stage.XXXXXXXX")
git clone --depth 1 "$repo" "$stage"
cd "$stage"
npm ci --no-audit --no-fund
npm run check
npm test
npm run build
sha=$(git rev-parse HEAD)
release="$base/releases/$sha"
if [[ -e "$release" ]]; then
  rm -rf "$stage"
else
  mv "$stage" "$release"
fi
stage=''
# The build runs under umask 077. Make only the public release tree readable
# by the unprivileged systemd user; secrets live outside this tree.
chmod -R a+rX "$release"

if ! id webtracker >/dev/null 2>&1; then
  useradd --system --home-dir /var/lib/web-tracker --create-home --shell /usr/sbin/nologin webtracker
fi
install -d -m 0700 -o webtracker -g webtracker /var/lib/web-tracker
install -d -m 0700 /etc/web-tracker

if [[ ! -f "$env_file" ]]; then
  # Do not overwrite a database or role created by another application.
  if command -v psql >/dev/null 2>&1; then
    if runuser -u postgres -- psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='webtracker'" | grep -q 1; then
      echo 'Existing webtracker database role without application environment. Inspect manually.' >&2
      exit 1
    fi
  fi
  DEBIAN_FRONTEND=noninteractive apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y postgresql postgresql-client
  systemctl is-active --quiet postgresql
  db_password=$(openssl rand -hex 32)
  admin_password=$(openssl rand -hex 32)
  vault_key=$(openssl rand -base64 32 | tr -d '\n')
  printf "CREATE ROLE webtracker LOGIN PASSWORD '%s';\n" "$db_password" | runuser -u postgres -- psql -v ON_ERROR_STOP=1 >/dev/null
  runuser -u postgres -- createdb --owner=webtracker webtracker
  tmp_env=$(mktemp /etc/web-tracker/.env.XXXXXXXX)
  {
    printf 'NODE_ENV=production\nHOST=127.0.0.1\nPORT=%s\nTRUST_PROXY=1\n' "$port"
    printf 'APP_ORIGIN=https://%s\nMILESTONE_SYNC_MINUTES=15\n' "$domain"
    printf 'DATABASE_URL=postgresql://webtracker:%s@127.0.0.1:5432/webtracker\n' "$db_password"
    printf 'ADMIN_PASSWORD=%s\nVAULT_KEY=%s\n' "$admin_password" "$vault_key"
  } > "$tmp_env"
  chmod 0600 "$tmp_env"
  mv "$tmp_env" "$env_file"
  # Only the SSH account can read this one-time login file. Remove it after saving the password.
  install -m 0600 -o ubuntu -g ubuntu /dev/null /home/ubuntu/.web-tracker-initial-login
  printf 'URL=https://%s\nADMIN_PASSWORD=%s\n' "$domain" "$admin_password" > /home/ubuntu/.web-tracker-initial-login
  chown ubuntu:ubuntu /home/ubuntu/.web-tracker-initial-login
  unset db_password admin_password vault_key
else
  echo 'Reusing the existing protected application environment and database.'
fi

ln -sfn "$release" "$base/.next"
mv -Tf "$base/.next" "$base/current"
cat > /etc/systemd/system/web-tracker.service <<EOF
[Unit]
Description=Web Tracker
After=network-online.target postgresql.service
Wants=network-online.target
Requires=postgresql.service

[Service]
Type=simple
User=webtracker
Group=webtracker
WorkingDirectory=$base/current
EnvironmentFile=$env_file
ExecStart=/usr/bin/node server/index.js
Restart=always
RestartSec=5
UMask=0077
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true
CapabilityBoundingSet=
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6
MemoryMax=768M

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable web-tracker
systemctl restart web-tracker
for attempt in {1..15}; do
  if curl -fsS "http://127.0.0.1:$port/api/health" | grep -q '"ok"'; then break; fi
  sleep 2
done
curl -fsS "http://127.0.0.1:$port/api/health" | grep -q '"ok"'

if ! grep -Fq "$domain {" "$caddy_file"; then
  caddy_backup=$(mktemp /etc/caddy/Caddyfile.web-tracker.XXXXXXXX)
  cp -p "$caddy_file" "$caddy_backup"
  cat >> "$caddy_file" <<EOF

$domain {
    reverse_proxy 127.0.0.1:$port
}
EOF
  caddy_changed=1
  caddy validate --config "$caddy_file" --adapter caddyfile
  systemctl reload caddy
fi

cat > /usr/local/sbin/web-tracker-backup <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
dest=/var/backups/web-tracker
file="$dest/webtracker-$(date -u +%Y%m%dT%H%M%SZ).dump"
pg_dump -Fc -f "$file" webtracker
pg_restore -l "$file" >/dev/null
find "$dest" -maxdepth 1 -name 'webtracker-*.dump' -type f -mtime +14 -delete
EOF
chmod 0755 /usr/local/sbin/web-tracker-backup
install -d -m 0700 -o postgres -g postgres /var/backups/web-tracker
cat > /etc/systemd/system/web-tracker-backup.service <<'EOF'
[Unit]
Description=Back up Web Tracker PostgreSQL database
After=postgresql.service
[Service]
Type=oneshot
User=postgres
ExecStart=/usr/local/sbin/web-tracker-backup
EOF
cat > /etc/systemd/system/web-tracker-backup.timer <<'EOF'
[Unit]
Description=Daily Web Tracker backup
[Timer]
OnCalendar=*-*-* 03:30:00 UTC
Persistent=true
[Install]
WantedBy=timers.target
EOF
systemctl daemon-reload
systemctl enable --now web-tracker-backup.timer
systemctl start web-tracker-backup.service

curl -fsS --retry 6 --retry-delay 5 "https://$domain/api/health" | grep -q '"ok"'
echo "Web Tracker core service is healthy at https://$domain"
echo "Release: $sha"
echo 'Screenshot capture remains disabled until an isolated worker is implemented and verified.'
echo 'Initial login is in /home/ubuntu/.web-tracker-initial-login; never paste it into chat.'
echo 'Back up VAULT_KEY off the VM separately before using the vault.'
