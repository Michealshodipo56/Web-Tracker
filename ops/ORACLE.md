# Oracle VM deployment (Ubuntu 24.04, ARM)

This procedure is tailored to the existing VM at `145.241.223.113`. It adds a separate PostgreSQL 16 database, systemd service bound to `127.0.0.1:4117`, and one Caddy route at `web-tracker.145-241-223-113.nip.io`. It does not change existing backend units or their ports. Review `oracle-deploy.sh` before executing it. Run as `sudo bash ops/oracle-deploy.sh` from a fresh clone of this repository on that VM. The script installs PostgreSQL through Ubuntu packages if Web Tracker has no environment file, builds a release, generates protected credentials locally, checks the local health endpoint, validates and reloads Caddy, and creates a daily PostgreSQL dump timer. On a failed Caddy/HTTPS step it restores the previous Caddyfile.

The initial admin login is written to `/home/ubuntu/.web-tracker-initial-login` with mode 0600. Read it privately, store it in a password manager, then delete that file. Never paste it into chat or a support ticket. `/etc/web-tracker/app.env` contains the database password and AES-256-GCM `VAULT_KEY`; keep it root-only. Back up the vault key through a separate secure channel away from the VM. A database dump alone cannot recover encrypted vault values if the key is lost. Never regenerate the key during an update or migration.

After installation, run `sudo bash /opt/web-tracker/current/ops/oracle-smoke.sh`. This imports the repository if necessary, syncs `MILESTONES.md`, tests a disposable encrypted secret, restarts only Web Tracker, creates a database dump, restores it to a temporary database, and removes the disposable secret. Check `systemctl status web-tracker web-tracker-backup.timer` and `journalctl -u web-tracker --since today` without publishing environment values. Confirm the HTTPS certificate and the browser login on the intended URL.

Backups are stored in `/var/backups/web-tracker` (postgres user, mode 0700) and retained for 14 days. Arrange an encrypted off-VM copy and a separate key backup; local dumps do not protect against VM loss. The backup restore verifier is `sudo bash /opt/web-tracker/current/ops/oracle-verify-backup.sh`.

## Rollback

Before an update, record `readlink -f /opt/web-tracker/current` and copy `/etc/caddy/Caddyfile` to a protected backup. If the new application release fails, atomically point `/opt/web-tracker/current` back at the previous release, then `sudo systemctl restart web-tracker`. If the new Caddy route fails, restore the saved Caddyfile, run `sudo caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile`, and `sudo systemctl reload caddy`. Do not delete the PostgreSQL database or replace `VAULT_KEY` during rollback. The deploy script retains prior release directories and creates a Caddyfile backup for a failed first installation.

## Remaining gate

The screenshot endpoint intentionally returns HTTP 503. Playwright must run in a separate, non-root sandbox with network egress rules denying loopback, private networks, Oracle metadata, and database access. Verify those rules against actual navigation and redirects before enabling screenshots. Until then, deployment of the complete requested feature set is **not verified**.
