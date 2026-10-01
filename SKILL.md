---
name: manyfold-cf-deploy
description: End-to-end workflow to build on local machine, push to GitHub, and deploy a Manyfold Agent web application to Cloudflare Workers (Vite + React 19 + Hono + D1). Automates D1 database creation, wrangler.jsonc binding, secret provisioning (ADMIN_PASSWORD, CONFIG_ENCRYPTION_KEY), and smoke tests.
version: 0.1.0
---

# Manyfold to Cloudflare Deployment Skill (`manyfold-cf-deploy`)

Use this skill when you or the user want to take a Manyfold Agent (or a starter template), package it into a full-stack Cloudflare Worker application, push it to a GitHub repository, and deploy it to Cloudflare Workers with persistent D1 storage and streaming A2A chat.

---

## Architecture Overview

```
Browser (React 19 SPA, dist/client)
   │  /api/* (run_worker_first)             All other requests → Static assets
   ▼
Hono Application in workerd (src/worker/index.ts)
   │ 
   ├── Admin Gate: ADMIN_PASSWORD middleware protects /api routes against unauthorized token burn
   ├── Security: Agent Bearer tokens are AES-GCM encrypted in Cloudflare D1
   └── Communication: A2A Protocol (message/stream over SSE) connected to Manyfold Agent
```

- **Runtime**: Cloudflare Workers (`workerd`).
- **Storage**: Cloudflare D1 (SQLite at the edge, zero-migration schema auto-initialized on first request).
- **Frontend**: React 19 + Vite.
- **Backend API**: Hono running inside the worker.
- **Identity & Auth**: Manyfold Device Code authorization flow + AES-GCM credential encryption in D1.

---

## Safety & Security Invariants

These rules are strictly enforced during every run:
1. **Never commit secrets**: `.dev.vars` must stay in `.gitignore`. Never hardcode `MF_API_TOKEN`, admin passwords, or encryption keys in git or client code.
2. **Always build before deploying**: `wrangler deploy` deploys `dist/client`. Never deploy without running `npm run build` or `npm run check` first.
3. **Keep `GET /api/health` returning 200 JSON**: This is the contract for Cloudflare Workers Builds and deployment smoke tests.
4. **Always set `ADMIN_PASSWORD` on public deployments**: Without an admin password, anyone with the worker URL can chat with the agent and exhaust the user's Manyfold credits.
5. **Set `CONFIG_ENCRYPTION_KEY` for multi-tenant / production security**: Key must be >= 32 characters, set via Cloudflare Secrets.

---

## 5-Step Execution Workflow

### Step 0: Pre-flight Environment Checks

Verify local tools and authentication before proceeding:
```bash
# Check binaries
node -v          # Must be >= 22
gh auth status   # Verify GitHub CLI login
npx wrangler whoami # Verify Cloudflare API authentication
mf whoami --json # Verify Manyfold CLI authentication
```

---

### Step 1: Scaffold & Customize Local Project

1. **Scaffold from Template**:
   If starting fresh, copy from the local starter or clone `manyfold-open/cloudflare-worker-starter`:
   ```bash
   cp -R /Users/zack/Desktop/cloudflare-worker-starter ./<app-name>
   cd <app-name>
   ```

2. **Customize Metadata**:
   - Update `name` in `package.json` and `wrangler.jsonc`.
   - Optionally update branding in `src/app/` or `index.html`.
   - If binding to a specific Manyfold Agent by default, configure it in `wrangler.jsonc` vars or app state.

3. **Install Dependencies**:
   ```bash
   npm install
   ```

---

### Step 2: Provision Cloudflare D1 Database

Every Manyfold Worker app requires a Cloudflare D1 database for sessions and encrypted credentials:

1. **Create the D1 database**:
   ```bash
   npx wrangler d1 create <app-name>-db --json
   ```
   Output gives `database_id` (UUID format, e.g. `xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx`).

2. **Update `wrangler.jsonc`**:
   Replace the placeholder `database_id` with the real UUID:
   ```jsonc
   "d1_databases": [
     {
       "binding": "DB",
       "database_name": "<app-name>-db",
       "database_id": "<REAL-DATABASE-ID>"
     }
   ]
   ```
   > [!WARNING]
   > Do NOT touch the `binding: "DB"` name, as the worker code relies on `env.DB`.

---

### Step 3: Local Verification

Run automated checks before pushing to Git:
```bash
# 1. Typecheck + Build + Wrangler Dry-Run
npm run check

# 2. Run unit tests
npm test
```
Both commands must pass with exit code 0.

---

### Step 4: Create GitHub Repository & Push

1. **Ensure `.gitignore` is intact**:
   Verify `.dev.vars`, `node_modules`, `dist`, and `.wrangler` are ignored.

2. **Initialize Git and commit**:
   ```bash
   git init
   git add .
   git commit -m "feat: initial commit for Manyfold Cloudflare Worker app"
   ```

3. **Create remote repository with GitHub CLI**:
   ```bash
   # Private repo (recommended initially):
   gh repo create <repo-name> --private --source=. --remote=origin --push

   # Or public repo:
   gh repo create <repo-name> --public --source=. --remote=origin --push
   ```

---

### Step 5: Deploy to Cloudflare & Set Production Secrets

#### Option A: Direct Deployment via Wrangler
```bash
npm run deploy
```
This outputs the deployment URL, e.g. `https://<app-name>.<subdomain>.workers.dev`.

#### Option B: Connect to Cloudflare Workers Builds (Git Continuous Deployment)
1. Go to Cloudflare Dashboard → **Workers & Pages** → **Create** → **Connect to Git**.
2. Select the GitHub repository.
3. Build command: `npm run build`
4. Deploy command: `npx wrangler deploy`
> [!IMPORTANT]
> If deploying via the web dashboard button, expand the "Advanced settings" section once before clicking Deploy to ensure build token fields initialize.

#### Configure Production Secrets (Mandatory)
Immediately set the access gate password:
```bash
# Set admin password to lock down chat & config endpoints
npx wrangler secret put ADMIN_PASSWORD

# Set custom AES-GCM encryption key (optional but recommended for production)
npx wrangler secret put CONFIG_ENCRYPTION_KEY
```

---

### Step 6: Post-Deployment Smoke Verification

1. **Check health endpoint**:
   ```bash
   curl -fsS https://<your-worker-url>/api/health
   # Expected: {"status":"ok"}
   ```

2. **Run automated smoke test suite**:
   ```bash
   npm run smoke -- https://<your-worker-url>
   ```
   Verifies:
   - `GET /api/health` returns HTTP 200 JSON
   - `GET /api/state` returns agents and connect configuration
   - `GET /` serves HTML with `#root` container
   - Invalid `/api/*` routes return JSON 404

3. **Complete Manyfold Agent Connection**:
   - Open `https://<your-worker-url>` in browser.
   - Enter your `ADMIN_PASSWORD` if prompted.
   - Click "Connect Agent" → Complete device authorization on Manyfold.
   - Send a test message to confirm streaming response.

---

## Troubleshooting Guide

| Issue | Cause | Solution |
| :--- | :--- | :--- |
| `npm run check` fails on `wrangler deploy --dry-run` | Invalid `database_id` or syntax error in `wrangler.jsonc` | Verify D1 UUID with `npx wrangler d1 list` |
| `smoke` test times out or fails on `/api/health` | Deployment propagation delay or worker crashed | Check Cloudflare Worker real-time logs via `npx wrangler tail` |
| Agent connection fails | Token or permissions missing | Ensure Manyfold account has granted access to the specific Agent ID |
| Anyone can chat without password | `ADMIN_PASSWORD` secret was not set | Run `npx wrangler secret put ADMIN_PASSWORD` immediately |
