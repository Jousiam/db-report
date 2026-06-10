#!/bin/bash
# Utilities: logging, html_escape, slugify.
# Sourced by oracle_db_report.sh — never run directly.

# --- Logging ---------------------------------------------------------------
# Le flag VERBOSE active log_debug (sinon silencieux).
VERBOSE="${VERBOSE:-0}"

log_info() {
    printf '[%s] [INFO]  %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >&2
}
log_warn() {
    printf '[%s] [WARN]  %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >&2
}
log_error() {
    printf '[%s] [ERROR] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >&2
}
log_debug() {
    [ "$VERBOSE" = "1" ] && printf '[%s] [DEBUG] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >&2 || true
}

# --- HTML escape ----------------------------------------------------------
# Echappe les caractères HTML dangereux dans un texte arbitraire.
# Usage : echo "Mon titre <test>" | html_escape
html_escape() {
    sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' \
        -e 's/"/\&quot;/g' -e "s/'/\&#39;/g"
}

# --- Slugify --------------------------------------------------------------
# Convertit un titre en identifiant CSS-safe (ASCII, minuscules, tirets).
# Usage : slug=$(slugify "Mon Beau Titre Accentué :")
slugify() {
    local s="$1"
    # Lower-case + remplace les caractères accentués courants
    s=$(echo "$s" | iconv -f UTF-8 -t ASCII//TRANSLIT 2>/dev/null || echo "$s")
    s=$(echo "$s" | tr '[:upper:]' '[:lower:]')
    # Tout caractère non-alphanumérique devient un tiret
    s=$(echo "$s" | sed 's/[^a-z0-9]/-/g; s/--*/-/g; s/^-//; s/-$//')
    # Garde-fou : si tout est vide
    [ -z "$s" ] && s="section"
    echo "$s"
}

# --- Title extraction from SQL file ---------------------------------------
# Cherche un marker `-- TITLE: ...` dans les 10 premières lignes du fichier.
# Fallback sur le basename si pas de marker.
extract_title() {
    local sql_file="$1"
    local title
    title=$(head -10 "$sql_file" | grep -i '^[[:space:]]*--[[:space:]]*TITLE:' | head -1 \
            | sed -E 's/^[[:space:]]*--[[:space:]]*TITLE:[[:space:]]*//I' \
            | sed -E 's/[[:space:]]*$//')
    if [ -z "$title" ]; then
        # Fallback : nom du fichier sans préfixe numérique
        title=$(basename "$sql_file" .sql | sed -E 's/^[0-9]+_//' | tr '_' ' ')
    fi
    echo "$title"
}
