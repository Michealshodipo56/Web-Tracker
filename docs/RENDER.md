# Render temporary hosting

The repository includes [render.yaml](../render.yaml) for a Render Blueprint: one Node web service and one PostgreSQL database. The Blueprint uses paid **Starter** web service and **Basic** database plans; confirm current pricing in Render before creating it. Nothing has been provisioned automatically.

## Setup

1. Open https://dashboard.render.com/select-repo?type=blueprint or Render Dashboard → New → Blueprint, connect GitHub and select `Michealshodipo56/Web-Tracker` on `main`. Review the proposed resources and billing before approving.
2. Set `ADMIN_PASSWORD` to a strong unique password (at least 16 characters).
3. Generate `VAULT_KEY` locally in a trusted environment using `openssl rand -base64 32` (32 bytes, base64). **Store a secure backup outside Render.** Never regenerate it for the same database, or existing secrets become unreadable.
4. Set `APP_ORIGIN` to the exact HTTPS URL assigned to your Render service, e.g. `https://web-tracker-xxxx.onrender.com`, with **no trailing slash**. If the URL is unknown during Blueprint creation, configure it in Render Environment immediately afterward, then redeploy.
5. `DATABASE_URL` is injected automatically from the Render database. Do not use a public database URL if an internal connection is available. `HOST=0.0.0.0` is necessary for Render port binding.
6. Deploy, visit `/api/health`, sign in, import a GitHub repository, sync milestones, and test storing/revealing/deleting a dummy secret. Confirm a service restart retains the project and secret.
7. Enable database backups and periodically test restore into a **separate** database. Back up the vault key separately. Render database backup availability depends on plan.

## Screenshot limitation

Screenshot capture remains **disabled and returns HTTP 503**. A browser process in the same Render web service would have access to internal networking; URL validation alone is not sufficient isolation. Do not set `ENABLE_SCREENSHOTS=true` or add `--no-sandbox` to work around this. A separate worker with enforced egress deny rules for private networks, loopback, cloud metadata, and internal database is needed, with a verified screenshot transfer mechanism. This can be added on Oracle.

## Migration to Oracle

Export PostgreSQL using `pg_dump` and restore with `pg_restore` into a new database, preserving UUIDs, sessions (or expire them), milestones, and encrypted secret records. Copy the **same** `VAULT_KEY` through an approved secret channel, set `APP_ORIGIN` to the new HTTPS URL, and point DNS at Oracle only after smoke tests. Keep Render available for rollback until verification passes. Do not log or commit secrets or database dumps.

## Known limitations

Automatic milestone refresh is polling (default every 15 minutes), not a webhook. GitHub rate limits apply. Screenshot previews are unavailable on this initial Render deployment. Deployment and end-to-end verification must be performed in the Render account; this file alone does not create services.
