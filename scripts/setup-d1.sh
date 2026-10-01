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

echo "==> Ensuring Cloudflare D1 database: $DB_NAME ..."

# 1. Check if database already exists
DB_ID=$(npx --yes wrangler d1 list 2>/dev/null | grep "$DB_NAME" | awk -F'│' '{print $2}' | tr -d ' ' || true)

# 2. If not found, create it (answering 'n' to auto-patch so we preserve our own schema & comments)
if [ -z "$DB_ID" ]; then
  echo "[+] Creating new D1 database $DB_NAME..."
  CREATE_OUT=$(echo "n" | npx --yes wrangler d1 create "$DB_NAME" 2>&1 || true)
  DB_ID=$(echo "$CREATE_OUT" | grep -o '"database_id": *"[^"]*"' | head -n1 | cut -d'"' -f4 || true)
  if [ -z "$DB_ID" ]; then
    DB_ID=$(npx --yes wrangler d1 list 2>/dev/null | grep "$DB_NAME" | awk -F'│' '{print $2}' | tr -d ' ' || true)
  fi
fi

if [ -z "$DB_ID" ]; then
  echo "[-] Could not determine database_id for $DB_NAME."
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
