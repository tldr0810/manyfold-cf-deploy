# Security Invariants & Credentials Checklist

When building and deploying a Manyfold Cloudflare Worker application, the following security constraints must be strictly adhered to:

## 1. Secrets Management
- **Never commit `.dev.vars`**: Local secrets (`ADMIN_PASSWORD`, `CONFIG_ENCRYPTION_KEY`, `MANYFOLD_API_BASE_URL`) live only in `.dev.vars` which is git-ignored.
- **Production Secrets via Wrangler**:
  ```bash
  # Required to prevent unauthorized use of your Manyfold quota
  npx wrangler secret put ADMIN_PASSWORD

  # Recommended for production to encrypt database-stored session tokens (>= 32 chars)
  npx wrangler secret put CONFIG_ENCRYPTION_KEY
  ```
- **No Token Leaks**: Manyfold device codes and agent bearer tokens must never appear in:
  - Client-side code / browser network logs
  - Worker console / log lines
  - Public Git history

## 2. Token Storage & Encryption
- Tokens stored in Cloudflare D1 are sealed with AES-GCM encryption (`src/worker/crypto.ts`).
- If `CONFIG_ENCRYPTION_KEY` is not explicitly set in Cloudflare Secrets, a local key is generated and stored in D1. Setting an explicit secret in production isolates key storage from data storage.

## 3. Network & Probing Safeguards
- **Health Probing**: The app must use `tasks/get` probe (`probeAgentAuth`) for connectivity tests, NEVER `message/send` (which consumes token quota and bills the user).
- **SSRF Protection**: Any agent-supplied URLs must be validated against `validateA2AUrl` before dispatching requests.
- **Replay Protection**: A2A `messageId`s are derived deterministically from database rows to prevent double-billing on network retries.

## 4. Origin & Gate Protections
- All `/api/*` routes (except `/api/health` and `/api/state`) must pass through the `ADMIN_PASSWORD` middleware.
- Origin headers are strictly checked to prevent Cross-Site Request Forgery.
