#!/bin/bash
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

echo -e "${YELLOW}This will delete all generated project files.${NC}"
read -rp "Are you sure? (y/N): " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || exit 0

rm -rf frontend backend docs nginx
rm -f AGENTS.md docker-compose.yml .gitignore Makefile

echo -e "${GREEN}Cleaned. Run ./init.sh to regenerate.${NC}"
echo -e "(README.md preserved — delete manually if needed)"
