# Web Tracker

GitHub-first website portfolio manager with milestone tracking, screenshots and an encrypted secrets vault. Built with React/Vite, Express, PostgreSQL and Playwright.

## Implemented

- Import repositories from `https://github.com/owner/repo` and retrieve GitHub metadata
- Parse Markdown checkbox milestones from `MILESTONES.md` (customizable path)
- Calculate project completion percentage and current stage
- Manually sync milestone progress from GitHub
- Configure deployed HTTPS website URL and capture screenshot on demand
- Store secrets encrypted using AES-256-GCM; list names without exposing values, reveal on explicit action
- Administrator password login, server-side session records and HTTP-only session cookies

## Local development

Node 22+ and PostgreSQL required. Run `npm install`, create a local PostgreSQL database, configure environment variables from `.env.example` **outside version control**, then `npm run dev` for the Vite frontend and `npm start` for the API. Vite development must proxy `/api` to the backend or use the same-origin production build. For a production deployment run `npm run build` and `npm start` with `NODE_ENV=production`.

Required: `DATABASE_URL`, `APP_ORIGIN`, `ADMIN_PASSWORD` (16+ characters), `VAULT_KEY` (32 random bytes base64). Optional: `GITHUB_TOKEN` for private repositories, `PORT`, `TRUST_PROXY`. Keep secrets outside Git and backed up securely. See `server/README.md`.

## Deployment handoff for ChatGPT Work

1. Inspect this repository and existing Oracle VM services without disrupting other deployments.
2. Confirm Node 22+, PostgreSQL and disk capacity. Run dependency installation, lint/build and smoke tests; fix any failures before going live.
3. Provision an isolated PostgreSQL database/user. Supply environment variables using a protected runtime secret store, not a committed `.env`.
4. Generate a unique high-entropy `VAULT_KEY` and strong administrator password. Set `APP_ORIGIN` to the exact HTTPS origin. Securely communicate initial login details using an approved secret-sharing mechanism.
5. Put Web Tracker behind existing Nginx/Caddy reverse proxy with TLS and a dedicated hostname, bind Node to localhost, configure restart and health checks.
6. **Screenshots require hardening**: run Chromium in a dedicated non-root sandboxed container/worker with no access to cloud metadata, internal IP ranges, local services or databases. Enforce egress network policy and request timeouts. Only then set `ENABLE_SCREENSHOTS=true`. Do not enable screenshots until isolation is verified.
7. Configure read-only GitHub token/App credentials only if private repos are needed; do not expose token to frontend.
8. Verify login, GitHub import, milestone sync, vault encryption/reveal/delete, screenshot capture, restart persistence, backups and recovery. Verify no secrets in logs or responses except explicit reveal.
9. Set up backups for PostgreSQL and the vault key (separately), and a safe key-rotation procedure. Set up a sync schedule or GitHub webhook with signature verification if automatic milestone updates are desired.
10. Report deployment URL, tests performed, outstanding risks and rollback procedure.

## Current limitations

This is an **implementation foundation, not a verified production deployment**. It has not been installed or run against an Oracle VM yet. Screenshots are disabled by default and require isolated execution. Milestone sync is currently manual (and attempted on import), not webhook-triggered. The login model is single-administrator, with no password recovery or multiuser permissions. The secret vault encrypts values server-side but the admin password is not a separate client-side decryption factor. Imported projects from the earlier browser-only version are not automatically migrated. Do not expose this to the internet without the deployment hardening and testing above.
