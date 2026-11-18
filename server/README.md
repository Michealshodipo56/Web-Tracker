# Backend notes

Node.js 22+ / PostgreSQL 15+ / Playwright Chromium.

Set DATABASE_URL, APP_ORIGIN, ADMIN_PASSWORD (16+ characters), VAULT_KEY (base64 32 random bytes), NODE_ENV=production, PORT=4000. Optional GITHUB_TOKEN for private repos and API rate limits; token must have read-only repository contents/metadata access. Never commit environment values.

The API has a single administrator account. Session cookies are HTTP-only, secure in production and SameSite Strict. POST/PATCH/DELETE require an exact Origin matching APP_ORIGIN. Secrets use AES-256-GCM with a fresh nonce and authenticated project/name metadata; vault key must be backed up separately. Losing it makes secrets unrecoverable. Rotate via a carefully planned decrypt/re-encrypt migration, not by simply replacing the key.

Screenshot capture of user-specified URLs may expose a browser to SSRF or exploits. **Production must enforce egress firewall rules** denying instance metadata (169.254.169.254), localhost, internal RFC1918/IPv6 networks, and database endpoints. Run Chromium as a non-root, restricted user with sandbox enabled in a separate worker/container. Do not expose the app to the public internet until this is done.

The screenshot endpoint currently returns 503 even when `ENABLE_SCREENSHOTS=true`: the in-process Chromium launcher was removed because DNS checks and request interception cannot enforce egress isolation. A dedicated worker and independently verified network policy are required before enabling capture. Milestones sync when imported, on request, and on an interval controlled by `MILESTONE_SYNC_MINUTES` (default 15). Private GitHub repositories require a server-side GitHub token. This server intentionally does not write milestones back to GitHub.
