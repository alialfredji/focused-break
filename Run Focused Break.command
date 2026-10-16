#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ ! -d "$PROJECT_DIR/dist/Focused Break.app" ]; then
  bash "$PROJECT_DIR/scripts/build.sh"
fi
open "$PROJECT_DIR/dist/Focused Break.app"
