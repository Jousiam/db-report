#!/bin/bash
#
# oracle_db_report.sh — Modernized Oracle DBA report generator (Bash version).
#
# Alternative compatible avec l'orchestrateur Yacine31/db_report d'origine, with:
#   - Section-level error isolation (one failing SQL doesn't kill the report)
#   - pgrep-based DB detection (+ /etc/oratab fallback)
#   - Modern HTML output with theme picker / copy-to-Word / search / back-to-top
#   - ISO 8601 dates everywhere
#
# Usage : ./oracle_db_report.sh [--sid SID] [--output-dir DIR]

set -uo pipefail   # PAS -e : on gère les erreurs section par section

# --- Resolve script dir (works through symlinks too) ----------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"
SQL_DIR="${SCRIPT_DIR}/sql"
TEMPLATES_DIR="${SCRIPT_DIR}/templates"

# shellcheck source=lib/utils.sh
source "${LIB_DIR}/utils.sh"
# shellcheck source=lib/detect.sh
source "${LIB_DIR}/detect.sh"
# shellcheck source=lib/render.sh
source "${LIB_DIR}/render.sh"

# --- CLI parsing ----------------------------------------------------------
TARGET_SID=""
OUTPUT_DIR="${OUTPUT_DIR:-${SCRIPT_DIR}/output}"
QUERY_TIMEOUT="${QUERY_TIMEOUT:-120}"
VERBOSE="${VERBOSE:-0}"
KEEP_DEBUG_TOC="${KEEP_DEBUG_TOC:-0}"

while [ $# -gt 0 ]; do
    case "$1" in
        --sid)            TARGET_SID="$2"; shift 2 ;;
        --output-dir)     OUTPUT_DIR="$2"; shift 2 ;;
        --query-timeout)  QUERY_TIMEOUT="$2"; shift 2 ;;
        --verbose|--debug) VERBOSE=1; KEEP_DEBUG_TOC=1; shift ;;
        -h|--help)
            cat <<EOF
Usage: $0 [OPTIONS]

Options:
  --sid SID              Target a specific Oracle SID (otherwise auto-detect)
  --output-dir DIR       Where to write reports (default: ./output)
  --query-timeout SECS   Max seconds per sqlplus query (default: 120). The
                         script will skip queries that exceed this timeout
                         instead of freezing.
  --verbose, --debug     Print per-query timing + keep the TOC debug log
                         alongside the HTML output (for diagnostics).
  -h, --help             Show this help

Environment :
  OUTPUT_DIR             Same as --output-dir
  QUERY_TIMEOUT          Same as --query-timeout
  VERBOSE=1              Same as --verbose
EOF
            exit 0 ;;
        *)
            log_error "Unknown argument: $1"
            exit 2 ;;
    esac
done

# Propage VERBOSE pour que log_debug le voie dans les sous-shells
export VERBOSE
log_debug "CLI parsed: TARGET_SID='${TARGET_SID}', QUERY_TIMEOUT=${QUERY_TIMEOUT}s, VERBOSE=${VERBOSE}"

# Force NLS_LANG en UTF-8 pour que les caractères accentués des littéraux SQL
# (verdicts en français) traversent sqlplus sans devenir des '?'. Si l'utilisateur
# a déjà défini NLS_LANG dans son environnement, on respecte son choix.
export NLS_LANG="${NLS_LANG:-AMERICAN_AMERICA.AL32UTF8}"
log_debug "NLS_LANG=${NLS_LANG}"

TIMESTAMP="$(date +%Y%m%d-%H%M)"
DAY_DIR="${OUTPUT_DIR}/$(date +%Y%m%d)"
mkdir -p "$DAY_DIR"

# Required tools check
for tool in sqlplus pgrep awk sed; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        log_error "Required tool not in PATH: $tool"
        exit 3
    fi
done

# --- System info section helpers ------------------------------------------
# Wrap arbitrary stdout in a <pre> tag with HTML escaping.
section_pre() {
    echo '<pre>'
    html_escape
    echo '</pre>'
}

# Try to read OS logs with graceful fallbacks (improvement vs version d'origine which
# just gave up if /var/log/messages was unreadable).
collect_os_logs() {
    if command -v journalctl >/dev/null 2>&1; then
        local out
        if out=$(journalctl --since "24 hours ago" --priority=err --no-pager 2>/dev/null) && [ -n "$out" ]; then
            echo "$out" | section_pre
            return 0
        fi
    fi
    if [ -r /var/log/messages ]; then
        grep -iE 'error|fail' /var/log/messages 2>/dev/null | tail -50 | section_pre
        return 0
    fi
    if command -v dmesg >/dev/null 2>&1; then
        dmesg --since=1hour 2>/dev/null | section_pre || \
        dmesg 2>/dev/null | tail -50 | section_pre
        return 0
    fi
    echo '<p><em>OS logs inaccessibles (journalctl, /var/log/messages, dmesg tous indisponibles).</em></p>'
}

write_system_sections() {
    local hostname slug
    hostname=$(hostname)

    # --- Hostname
    slug=$(slugify "Hostname")
    write_section_open "Hostname" "$slug"
    toc_add_link "Hostname" "$slug"
    echo "<p><strong>$(printf '%s' "$hostname" | html_escape)</strong></p>" >> "$HTML_FILE"
    write_section_close

    # --- Uptime
    slug=$(slugify "Uptime")
    write_section_open "Uptime" "$slug"
    toc_add_link "Uptime" "$slug"
    uptime | section_pre >> "$HTML_FILE"
    write_section_close

    # --- Mémoire
    slug=$(slugify "Mémoire physique")
    write_section_open "Mémoire physique" "$slug"
    toc_add_link "Mémoire physique" "$slug"
    {
        if command -v free >/dev/null 2>&1; then
            free -m | section_pre
        fi
        if [ -r /proc/meminfo ]; then
            echo '<p><em>/proc/meminfo MemTotal :</em></p>'
            grep '^MemTotal' /proc/meminfo | section_pre
        fi
    } >> "$HTML_FILE"
    write_section_close

    # --- CPU
    slug=$(slugify "CPU")
    write_section_open "CPU" "$slug"
    toc_add_link "CPU" "$slug"
    if command -v lscpu >/dev/null 2>&1; then
        lscpu | section_pre >> "$HTML_FILE"
    else
        echo '<p><em>lscpu indisponible.</em></p>' >> "$HTML_FILE"
    fi
    write_section_close

    # --- Stockage
    slug=$(slugify "Stockage")
    write_section_open "Stockage" "$slug"
    toc_add_link "Stockage" "$slug"
    {
        df -h | section_pre
        if command -v lsblk >/dev/null 2>&1; then
            echo '<p><em>lsblk :</em></p>'
            lsblk | section_pre
        fi
    } >> "$HTML_FILE"
    write_section_close

    # --- Oratab
    slug=$(slugify "Contenu /etc/oratab")
    write_section_open "Contenu /etc/oratab" "$slug"
    toc_add_link "Contenu /etc/oratab" "$slug"
    if [ -r /etc/oratab ]; then
        section_pre < /etc/oratab >> "$HTML_FILE"
    else
        echo '<p><em>/etc/oratab inaccessible.</em></p>' >> "$HTML_FILE"
    fi
    write_section_close

    # --- Listeners
    slug=$(slugify "Listeners")
    write_section_open "Listeners" "$slug"
    toc_add_link "Listeners" "$slug"
    ps -eo user,pid,etime,cmd 2>/dev/null | grep -E 'tnslsnr' | grep -v grep | section_pre >> "$HTML_FILE" \
        || echo '<p><em>Aucun process listener trouvé.</em></p>' >> "$HTML_FILE"
    write_section_close

    # --- OS logs (with fallback chain)
    slug=$(slugify "Erreurs OS récentes")
    write_section_open "Erreurs OS récentes" "$slug"
    toc_add_link "Erreurs OS récentes" "$slug"
    collect_os_logs >> "$HTML_FILE"
    write_section_close
}

# --- SQL section execution ------------------------------------------------
# Runs one SQL file via sqlplus and wraps the output in a <section>.
# Catches errors (sqlplus failures, ORA-* in output) gracefully.
run_sql_section() {
    local sql_file="$1"
    local title slug
    title=$(extract_title "$sql_file")
    # Per-SID slug : on préfixe avec le SID slugifié pour que les sections d'une
    # même requête soient uniquement identifiables (CDBPROD/coherence-memoire vs
    # DBSTBY/coherence-memoire). Sinon les liens TOC scrollent vers la première
    # occurrence — qui est cachée par .hidden quand l'onglet n'est pas actif.
    local sid_prefix=""
    if [ -n "${CURRENT_SID:-}" ]; then
        sid_prefix="$(slugify "$CURRENT_SID")-"
    fi
    slug="${sid_prefix}$(slugify "$title")"
    local basename
    basename=$(basename "$sql_file")

    # Per-query timeout : on lit un éventuel commentaire `-- TIMEOUT: N` dans les
    # 10 premières lignes du fichier SQL. Permet de réduire le timeout sur les
    # requêtes connues comme flaky (ex: 27 sur les CDB avec SYSAUX cassée) pour
    # ne pas perdre 120s à chaque run.
    local effective_timeout="$QUERY_TIMEOUT"
    local custom_timeout
    custom_timeout=$(head -10 "$sql_file" | grep -oE '^-- TIMEOUT:[[:space:]]*[0-9]+' | grep -oE '[0-9]+' | head -1)
    if [ -n "$custom_timeout" ] && [ "$custom_timeout" -gt 0 ]; then
        effective_timeout="$custom_timeout"
        log_debug "    Using per-query timeout: ${effective_timeout}s (from annotation)"
    fi

    write_section_open "$title" "$slug"
    toc_add_link "$title" "$slug"
    log_debug "    TOC append: SID=${CURRENT_SID:-shared} slug='${slug}' file=${basename}"

    local sqlplus_out rc
    local t_start t_end t_elapsed
    t_start=$(date +%s%N 2>/dev/null || date +%s)

    set +e
    # `timeout` kills the entire pipeline if sqlplus takes too long, preventing
    # the script from freezing indefinitely on a single bad query.
    sqlplus_out=$(timeout --kill-after=5 "$effective_timeout" \
        bash -c "cat '${SQL_DIR}/header.sql' '${sql_file}' | sqlplus -s -L '/ as sysdba'" 2>&1)
    rc=$?
    set +e

    t_end=$(date +%s%N 2>/dev/null || date +%s)
    if [ ${#t_end} -gt 12 ]; then
        t_elapsed=$(( (t_end - t_start) / 1000000 ))
        log_debug "    Query ${basename} took ${t_elapsed} ms (rc=${rc})"
    else
        t_elapsed=$(( t_end - t_start ))
        log_debug "    Query ${basename} took ${t_elapsed} s (rc=${rc})"
    fi

    if [ $rc -eq 124 ] || [ $rc -eq 137 ]; then
        # 124 = TERM by timeout, 137 = KILL (SIGKILL after --kill-after)
        log_warn "    ⏱  TIMEOUT (${effective_timeout}s) on ${basename} for SID=${CURRENT_SID:-?}"
        {
            echo '<p class="highlight"><strong>Requête interrompue (timeout)</strong></p>'
            echo "<p>Cette requête a dépassé la limite de ${effective_timeout} secondes et a été interrompue pour éviter un blocage du script. Augmentez le timeout avec <code>--query-timeout</code> ou via l'annotation <code>-- TIMEOUT: N</code> en tête du fichier SQL si nécessaire.</p>"
            echo "<pre>Fichier : ${basename}</pre>"
        } >> "$HTML_FILE"
    elif [ $rc -ne 0 ] && [ -z "$sqlplus_out" ]; then
        echo "<p class=\"highlight\"><strong>sqlplus failed (exit $rc) for $(basename "$sql_file" | html_escape)</strong></p>" >> "$HTML_FILE"
    else
        # Détection intelligente : la sortie peut contenir des erreurs ORA-* ET une
        # table valide (cas typique : un ALTER SESSION en header qui plante mais le
        # SELECT principal qui réussit). On vérifie les DEUX et on affiche les deux
        # plutôt que de masquer la table.
        local has_ora=0 has_table=0
        echo "$sqlplus_out" | grep -qE '^(ORA-|SP2-)[0-9]+' && has_ora=1
        echo "$sqlplus_out" | grep -q '<table' && has_table=1

        # Nettoyage défensif : sqlplus en MARKUP HTML peut padder les cellules avec
        # des espaces quand COLUMN ... FORMAT aN est utilisé (pour éviter la
        # troncature des en-têtes). On retire ces espaces de début/fin DANS les
        # cellules <td>/<th> pour un rendu propre à l'écran et au collage Word.
        trim_html_cells() {
            sed -E 's#(<t[dh][^>]*>)[[:space:]]+#\1#g; s#[[:space:]]+(</t[dh]>)#\1#g'
        }

        if [ "$has_ora" = "1" ] && [ "$has_table" = "0" ]; then
            # Pure error, no table — full error display
            {
                echo '<p class="highlight"><strong>Erreur Oracle :</strong></p>'
                echo '<pre>'
                echo "$sqlplus_out" | grep -E '^(ORA-|SP2-)' | head -10
                echo '</pre>'
            } >> "$HTML_FILE"
        elif [ "$has_ora" = "1" ] && [ "$has_table" = "1" ]; then
            # Both error AND table — show warning above the table
            {
                echo '<p class="highlight"><strong>Avertissement (erreur non-bloquante) :</strong></p>'
                echo '<pre>'
                echo "$sqlplus_out" | grep -E '^(ORA-|SP2-)' | head -5
                echo '</pre>'
                echo "$sqlplus_out" | awk '/<table/,/<\/table>/' | trim_html_cells
            } >> "$HTML_FILE"
        else
            # Normal HTML table output (no errors)
            echo "$sqlplus_out" | trim_html_cells >> "$HTML_FILE"
        fi
    fi

    write_section_close
}

# --- Per-SID database queries (assumes HTML_FILE is already opened) ------
# Runs all SQL files for one SID, wrapped in a db-group with data-sid attr.
run_db_queries_for_sid() {
    local sid="$1"
    local hostname="$2"
    CURRENT_SID="$sid"

    local t_sid_start
    t_sid_start=$(date +%s)
    log_info "▶ Starting SID=${sid}"

    # Set up Oracle environment for this SID
    if ! grep -q "^${sid}:" /etc/oratab 2>/dev/null; then
        log_warn "${sid} not found in /etc/oratab — environment may be incomplete"
    fi
    export ORAENV_ASK=NO
    export ORACLE_SID="$sid"
    if command -v oraenv >/dev/null 2>&1; then
        # shellcheck source=/dev/null
        . oraenv -s >/dev/null 2>&1 || log_warn "oraenv -s failed for ${sid}"
    fi
    log_debug "  ORACLE_HOME=${ORACLE_HOME:-unset} ORACLE_SID=${ORACLE_SID}"

    log_info "  Running database SQL queries for ${sid}"
    local sql_files=( "${SQL_DIR}/database/"*.sql )
    local n=${#sql_files[@]}
    local group_title="Configuration de la base ${sid}"

    log_debug "  TOC: opening group '${group_title}' (data-sid=${sid})"
    toc_start_group "$group_title" "$sid"
    write_group_header "$group_title" "$n" "$sid"
    for sql_file in "${sql_files[@]}"; do
        log_info "    → $(basename "$sql_file")"
        run_sql_section "$sql_file"
    done
    write_group_footer
    log_debug "  TOC: closing group for ${sid}"
    toc_end_group

    local t_sid_elapsed=$(( $(date +%s) - t_sid_start ))
    log_info "◀ Completed SID=${sid} in ${t_sid_elapsed}s ($n queries)"
    CURRENT_SID=""
}

# --- Combined report generation (single HTML for all detected SIDs) -------
generate_combined_report() {
    local hostname
    hostname=$(hostname)
    local sids_arr=("$@")
    local n_sids=${#sids_arr[@]}

    log_info "=== Generating combined report for ${n_sids} SID(s): ${sids_arr[*]} ==="

    # Output file name reflects the multi-DB nature
    local fname_suffix
    if [ "$n_sids" -eq 1 ]; then
        fname_suffix="${sids_arr[0]}"
    else
        fname_suffix="multi-${n_sids}db"
    fi
    HTML_FILE="${DAY_DIR}/Rapport_${hostname}_${fname_suffix}_${TIMESTAMP}.html"
    TOC_FILE="$(mktemp)"
    : > "$HTML_FILE"
    : > "$TOC_FILE"
    # shellcheck disable=SC2064
    trap "rm -f \"$TOC_FILE\"" EXIT INT TERM

    # Report metadata
    local report_title
    if [ "$n_sids" -eq 1 ]; then
        report_title="Rapport de base de données ${sids_arr[0]} sur ${hostname}"
    else
        report_title="Rapport multi-bases sur ${hostname} (${n_sids} instances)"
    fi
    local current_date
    current_date=$(date '+%Y-%m-%d %H:%M')
    local sids_csv
    sids_csv=$(IFS=', '; echo "${sids_arr[*]}")
    local meta_html=""
    meta_html+="<div class=\"meta-item\"><span class=\"meta-label\">Date</span><span class=\"meta-value\">$(printf '%s' "$current_date" | html_escape)</span></div>"
    meta_html+="<div class=\"meta-item\"><span class=\"meta-label\">Hostname</span><span class=\"meta-value\">$(printf '%s' "$hostname" | html_escape)</span></div>"
    if [ "$n_sids" -eq 1 ]; then
        meta_html+="<div class=\"meta-item\"><span class=\"meta-label\">SID</span><span class=\"meta-value\">$(printf '%s' "${sids_arr[0]}" | html_escape)</span></div>"
    else
        meta_html+="<div class=\"meta-item\"><span class=\"meta-label\">SIDs</span><span class=\"meta-value\">$(printf '%s' "$sids_csv" | html_escape)</span></div>"
        meta_html+="<div class=\"meta-item\"><span class=\"meta-label\">Bases</span><span class=\"meta-value\">${n_sids}</span></div>"
    fi

    # 1. HTML skeleton + sidebar opening (with TOC placeholder)
    write_html_header "$report_title" "$meta_html"

    # 2. System info group (shared — no SID attribution)
    log_info "Collecting system info (shared across all SIDs)"
    toc_start_group "Configuration système (hôte)"
    write_group_header "Configuration système (hôte)" "8"
    write_system_sections
    write_group_footer
    toc_end_group

    # 3. DB tabs bar (only if multiple SIDs)
    if [ "$n_sids" -gt 1 ]; then
        write_db_tabs "${sids_arr[@]}"
    fi

    # 4. Per-SID database groups
    for sid in "${sids_arr[@]}"; do
        run_db_queries_for_sid "$sid" "$hostname"
    done

    # 5. Footer + finalize TOC
    write_html_footer

    # TOC diagnostic: log size + group/link counts + group NAMES before injection
    local toc_size toc_groups toc_links
    toc_size=$(wc -c < "$TOC_FILE" 2>/dev/null || echo 0)
    toc_groups=$(grep -c 'class="toc-group' "$TOC_FILE" 2>/dev/null || echo 0)
    toc_links=$(grep -c '<li><a class="toc-link"' "$TOC_FILE" 2>/dev/null || echo 0)
    log_info "TOC stats before injection: ${toc_size} bytes, ${toc_groups} groups, ${toc_links} links"

    # Always list the actual group titles present in TOC — helps diagnose missing entries
    if [ -s "$TOC_FILE" ]; then
        local toc_titles
        toc_titles=$(grep -oE 'toc-group-title">[^<]+' "$TOC_FILE" | sed 's/toc-group-title">/  - /' || true)
        if [ -n "$toc_titles" ]; then
            log_info "TOC groups actually present:"
            echo "$toc_titles" | while IFS= read -r t; do log_info "$t"; done
        fi
    fi

    local expected_groups=$(( n_sids + 1 ))
    if [ "$toc_groups" -lt "$expected_groups" ]; then
        log_warn "TOC has ${toc_groups} groups but expected ${expected_groups} (system + ${n_sids} SIDs)"
        log_warn "→ Some toc_start_group calls didn't reach TOC_FILE. Run with --verbose for per-call trace."
        # Force-keep the TOC debug file even without --verbose when something is off
        KEEP_DEBUG_TOC=1
    fi

    finalize_toc

    if [ "$KEEP_DEBUG_TOC" = "1" ]; then
        local toc_debug_path="${HTML_FILE%.html}.toc-debug.txt"
        cp "$TOC_FILE" "$toc_debug_path" 2>/dev/null && \
            log_info "TOC debug file kept at: $toc_debug_path"
    fi

    log_info "Report generated: $HTML_FILE"
    rm -f "$TOC_FILE"
    trap - EXIT INT TERM
}

# --- Main ------------------------------------------------------------------
log_info "Starting DB Report v2.9 (bash version)"

if [ -n "$TARGET_SID" ]; then
    SIDS_TO_PROCESS="$TARGET_SID"
else
    SIDS_TO_PROCESS=$(detect_running_sids)
    if [ -z "$SIDS_TO_PROCESS" ]; then
        log_error "No running Oracle databases detected. Use --sid to target a specific instance."
        exit 1
    fi
    log_info "Detected SIDs: $(echo "$SIDS_TO_PROCESS" | tr '\n' ' ')"
fi

# Build SID array from the newline-separated list
SIDS_ARR=()
while IFS= read -r sid; do
    [ -z "$sid" ] && continue
    SIDS_ARR+=("$sid")
done <<< "$SIDS_TO_PROCESS"

if [ ${#SIDS_ARR[@]} -eq 0 ]; then
    log_error "Empty SID list"
    exit 1
fi

# Single combined report for all SIDs (tabs visible when multiple)
if ! generate_combined_report "${SIDS_ARR[@]}"; then
    log_error "Combined report generation failed"
    exit 1
fi

log_info "Done."
exit 0
