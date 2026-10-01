# Manyfold Cloudflare Deployment Skill (`manyfold-cf-deploy`)

A reusable AI Agent Skill that automates the end-to-end workflow of:
1. Scaffolding a full-stack Manyfold-connected app locally (Vite + React 19 + Hono + Cloudflare D1).
2. Creating and binding the Cloudflare D1 database.
3. Checking and pushing the code to a GitHub repository (`gh repo create`).
4. Deploying to Cloudflare Workers (`npx wrangler deploy`) and setting security secrets (`ADMIN_PASSWORD`, `CONFIG_ENCRYPTION_KEY`).
5. Running smoke verification (`GET /api/health` and `npm run smoke`).

---

## Installation & Usage

### 1. In Coding Agents (Antigravity, Claude Code, Codex)
Add this directory to your skills directory:
```bash
# Example: For Claude / Shared Agents skills
ln -s /Users/zack/dev/manyfold-cf-deploy ~/.agents/skills/manyfold-cf-deploy
```

### 2. In Manyfold Agent Library
Publish directly to your Manyfold personal skill library:
```bash
mf skills library publish /Users/zack/dev/manyfold-cf-deploy
```

---

## Directory Structure

```
manyfold-cf-deploy/
├── SKILL.md                  # Main Skill definition & step-by-step workflow
├── README.md                 # Overview and usage instructions
├── scripts/
│   ├── verify-env.sh         # Pre-flight environment check
│   └── setup-d1.sh           # Cloudflare D1 provisioning & wrangler.jsonc updater
└── references/
    └── security-invariants.md# Security, encryption & access checklist
```
