#!/bin/bash
# Génère un rapport Word à partir d'un rapport HTML DB Report déjà produit.
# Nécessite python3 + python-docx (pip install python-docx) côté DB Report.
#
# Usage:
#   ./generate_word.sh <rapport.html> <rapport.docx> [--client NOM] [--logo logo.png]
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

HTML="$1"; shift
DOCX="$1"; shift
CLIENT="CLIENT"
LOGO=""
TITLE="Rapport Mensuel des Bases de Données"

while [ $# -gt 0 ]; do
  case "$1" in
    --client) CLIENT="$2"; shift 2 ;;
    --logo)   LOGO="$2"; shift 2 ;;
    --title)  TITLE="$2"; shift 2 ;;
    *) echo "Option inconnue: $1"; exit 2 ;;
  esac
done

TMP_JSON="$(mktemp --suffix=.json)"
trap "rm -f $TMP_JSON" EXIT

python3 "$SCRIPT_DIR/python/html_to_json.py" "$HTML" "$TMP_JSON" --client "$CLIENT" --title "$TITLE"

if [ -n "$LOGO" ]; then
  python3 "$SCRIPT_DIR/python/word_builder.py" "$TMP_JSON" "$DOCX" --logo "$LOGO"
else
  python3 "$SCRIPT_DIR/python/word_builder.py" "$TMP_JSON" "$DOCX"
fi
echo "Rapport Word: $DOCX"
