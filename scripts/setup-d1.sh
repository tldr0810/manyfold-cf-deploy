#!/usr/bin/env bash
set -euo pipefail

# Usage: ./setup-d1.sh <project-dir> [database-name]
PROJECT_DIR="${1:-.}"
CONFIG_FILE="$PROJECT_DIR/wrangler.jsonc"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "[-] wrangler.jsonc not found in $PROJECT_DIR"
  exit 1
fi

APP_NAME=$(grep -o '"name": *"[^"]*"' "$CONFIG_FILE" | head -n1 | cut -d'"' -f4 || echo "manyfold-app")
DB_NAME="${2:-${APP_NAME}-db}"

echo "==> Creating Cloudflare D1 database: $DB_NAME ..."

# Run wrangler d1 create and capture output
D1_OUTPUT=$(npx --yes wrangler d1 create "$DB_NAME" --json 2>&1 || true)

# Extract database_id
DB_ID=$(echo "$D1_OUTPUT" | grep -o '"database_id": *"[^"]*"' | head -n1 | cut -d'"' -f4 || echo "")

if [ -z "$DB_ID" ]; then
  # Check if database already exists
  echo "[!] Failed to create or database already exists. Checking existing D1 databases..."
  LIST_OUTPUT=$(npx --yes wrangler d1 list --json 2>/dev/null || echo "[]")
  DB_ID=$(echo "$LIST_OUTPUT" | node -e '
    const fs = require("fs");
    const input = fs.readFileSync(0, "utf-8");
    try {
      const dbs = JSON.parse(input);
      const target = dbs.find(d => d.name === process.argv[1]);
      if (target) process.stdout.write(target.uuid || target.database_id || "");
    } catch {}
  ' "$DB_NAME")
fi

if [ -z "$DB_ID" ]; then
  echo "[-] Could not determine database_id for $DB_NAME."
  echo "Wrangler output:"
  echo "$D1_OUTPUT"
  exit 1
fi

echo "[+] Got D1 database_id: $DB_ID"
echo "==> Updating $CONFIG_FILE with database_name: $DB_NAME and database_id: $DB_ID ..."

# Safely replace database_id and database_name in wrangler.jsonc using node
node -e '
  const fs = require("fs");
  const file = process.argv[1];
  const dbName = process.argv[2];
  const dbId = process.argv[3];

  let content = fs.readFileSync(file, "utf-8");
  // Replace database_id
  content = content.replace(/"database_id":\s*"[^"]*"/, `"database_id": "${dbId}"`);
  // Replace database_name
  content = content.replace(/"database_name":\s*"[^"]*"/, `"database_name": "${dbName}"`);

  fs.writeFileSync(file, content, "utf-8");
' "$CONFIG_FILE" "$DB_NAME" "$DB_ID"

echo "[+] Successfully updated $CONFIG_FILE with D1 configuration!"
