#!/usr/bin/env bash
# Run as root on the VM. Restores the newest dump to an isolated temporary DB.
set -Eeuo pipefail
umask 077
[[ $EUID -eq 0 ]] || { echo 'Run with sudo.' >&2; exit 1; }
dump=$(find /var/backups/web-tracker -maxdepth 1 -name 'webtracker-*.dump' -type f -printf '%T@ %p\n' | sort -nr | head -1 | cut -d' ' -f2-)
[[ -n "$dump" ]] || { echo 'No Web Tracker backup found.' >&2; exit 1; }
verify_db="webtracker_verify_$$"
cleanup() { runuser -u postgres -- dropdb --if-exists "$verify_db" >/dev/null 2>&1 || true; }
trap cleanup EXIT
runuser -u postgres -- createdb "$verify_db"
runuser -u postgres -- pg_restore --no-owner --no-acl --exit-on-error -d "$verify_db" "$dump"
runuser -u postgres -- psql -v ON_ERROR_STOP=1 -d "$verify_db" -tAc 'SELECT count(*) FROM projects; SELECT count(*) FROM secrets;' >/dev/null
echo 'Backup restored successfully to a temporary database; projects and secrets tables are readable.'
