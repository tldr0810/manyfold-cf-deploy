#!/usr/bin/env bash
set -euo pipefail

echo "==> Checking required CLI tools and authentication..."

# 1. Check Node
if ! command -v node >/dev/null 2>&1; then
  echo "[-] node is not installed or not in PATH."
  exit 1
fi
node_version=$(node -v | sed 's/v//')
major_version=$(echo "$node_version" | cut -d. -f1)
if [ "$major_version" -lt 22 ]; then
  echo "[-] Node.js version must be >= 22 (current: v$node_version)."
  exit 1
fi
echo "[+] Node.js v$node_version detected."

# 2. Check Git & GitHub CLI
if ! command -v git >/dev/null 2>&1; then
  echo "[-] git is not installed."
  exit 1
fi
if ! command -v gh >/dev/null 2>&1; then
  echo "[-] GitHub CLI (gh) is not installed."
  exit 1
fi
if ! gh auth status >/dev/null 2>&1; then
  echo "[-] gh is not authenticated. Please run 'gh auth login'."
  exit 1
fi
echo "[+] GitHub CLI authenticated ($(gh auth status 2>&1 | grep 'Logged in to' | head -n1 | xargs))."

# 3. Check Wrangler
if ! npx --yes wrangler whoami >/dev/null 2>&1; then
  echo "[-] Cloudflare Wrangler is not authenticated. Set CLOUDFLARE_API_TOKEN or run 'npx wrangler login'."
  exit 1
fi
echo "[+] Cloudflare Wrangler authenticated."

# 4. Check Manyfold CLI
MF_BIN="${MF_BIN:-$(command -v mf || echo "$HOME/.local/bin/mf")}"
if [ -x "$MF_BIN" ]; then
  mf_whoami=$("$MF_BIN" whoami --json 2>/dev/null || echo "{}")
  mf_email=$(echo "$mf_whoami" | grep -o '"email": *"[^"]*"' | cut -d'"' -f4 || echo "")
  if [ -n "$mf_email" ]; then
    echo "[+] Manyfold CLI authenticated ($mf_email)."
  else
    echo "[!] Manyfold CLI found but not logged in. Run 'mf login'."
  fi
else
  echo "[!] Manyfold CLI not found (optional for deployment, needed for agent management)."
fi

echo "==> All required pre-flight checks passed!"
