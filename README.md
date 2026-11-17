# Web Tracker — Sitefolio

A personal website project dashboard built with React and Vite.

## Run

```bash
npm install
npm run dev
```

## Features

- Add, edit, search and delete website projects
- Manage descriptions, statuses, categories, live links and GitHub repositories
- Task checklists and automatically calculated progress
- Project notes and credential **references**
- Export/import JSON backups

## Security and storage

Project data is stored in **browser localStorage**, not a server. Do **not** store API keys, tokens, passwords or private keys in project records, notes, or JSON backups. Save only a reference to the secret in a secure password manager. Browser data is device-specific; export backups regularly. This is not an encrypted vault or cloud sync service.
