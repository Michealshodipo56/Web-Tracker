# Web Tracker

A private, GitHub-powered workspace for keeping personal software projects organized. Web Tracker brings repository details, milestone progress, deployment links, and encrypted project credentials into one straightforward dashboard.

## What it does

- **Import from GitHub:** Add a project using its repository URL. Web Tracker retrieves its name, description, default branch, and available website link.
- **Track progress:** Read Markdown checkboxes from a repository's `MILESTONES.md` (or another configured Markdown file), group tasks by heading, and calculate completion percentages.
- **Stay up to date:** Sync milestones manually or through scheduled server-side polling (15 minutes by default).
- **Document projects:** Edit each project's description and keep its deployed HTTPS website URL alongside its GitHub repository.
- **Protect credentials:** Store project secrets encrypted with AES-256-GCM; values are revealed only on request.
- **Keep it private:** Single-administrator login backed by server-side sessions and HTTP-only cookies.

Web Tracker intentionally **does not capture website screenshots**. The focus is reliable project tracking without a browser automation service.

## How it works

1. Sign in to your workspace.
2. Paste a GitHub repository URL and import it.
3. Add a `MILESTONES.md` file containing Markdown checkboxes, such as:

```md
# Planning
- [x] Define the project scope
- [x] Create the repository

# Development
- [x] Build the first version
- [ ] Add tests
- [ ] Deploy the application
```

4. Open a project to view progress, update its description and deployment URL, sync milestones, or manage its encrypted credentials.

The milestone file stays in GitHub; Web Tracker reads it rather than modifying your repository.

## Technology

| Layer | Technology |
| --- | --- |
| Frontend | React, Vite, CSS |
| API | Node.js, Express |
| Database | PostgreSQL |
| Encryption | AES-256-GCM |
| Repository integration | GitHub REST API |
| Hosting | Vercel frontend, Oracle Cloud backend |

## Deployment

The frontend can run on Vercel, while the API and PostgreSQL run on Oracle Cloud.

- `vercel.json` forwards `/api/*` to the configured Oracle HTTPS API. Update its destination if the backend hostname changes.
- Set `APP_ORIGIN` to the approved Oracle website origin and `FRONTEND_ORIGIN` to the exact Vercel frontend origin.
- Keep the API behind HTTPS and its Node listener bound to localhost.
- Store credentials in a protected environment file or secret manager, **never in Git**.

See [Oracle deployment guidance](ops/ORACLE.md) and [server documentation](server/README.md) for additional operational details.

## Local development

Requires Node.js 22+ and PostgreSQL.

```bash
npm ci
npm test
npm run check
npm run dev
```

In a separate terminal, start the API:

```bash
npm start
```

Vite proxies `/api` to `http://127.0.0.1:4000` in development. Configure the backend environment using [`.env.example`](.env.example). Required variables are `DATABASE_URL`, `ADMIN_PASSWORD`, `VAULT_KEY` (a base64-encoded 32-byte key), and the appropriate `APP_ORIGIN` for production. `FRONTEND_ORIGIN` optionally permits a separate frontend. Optional `GITHUB_TOKEN` supports authenticated GitHub API access. Keep the vault key backed up separately from the database.

To build the frontend, run `npm run build`.

## Security and limitations

Web Tracker is designed as a **single-user personal workspace**, not a multi-tenant collaboration platform. Protect your administrator password, HTTPS configuration, database backups, and vault key. The vault key is required to decrypt existing secrets; changing or losing it can make them unrecoverable.

Milestone synchronization depends on GitHub availability and a running API process. The screenshot API is disabled and returns an error by design. Password recovery, team accounts, and advanced role permissions are not currently implemented.

## Project repository

[GitHub — Michealshodipo56/Web-Tracker](https://github.com/Michealshodipo56/Web-Tracker)
