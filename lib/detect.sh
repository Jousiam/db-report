#!/bin/bash
# Détection des instances Oracle sur l'hôte.
# Stratégie : pgrep prioritaire, fallback /etc/oratab.

# Liste les SIDs des bases utilisateur en cours d'exécution (un par ligne).
# Exclut +ASM, APX*, MGMTDB.
detect_running_sids() {
    local sids=""

    # Primary : parcourir les process et matcher EXACTEMENT le premier argument
    # qui doit commencer par ora_pmon_ (et pas juste contenir cette chaîne
    # dans la cmdline, ce qui matcherait ce script lui-même).
    if command -v ps >/dev/null 2>&1; then
        sids=$(ps -eo args= 2>/dev/null \
               | awk '$1 ~ /^ora_pmon_/ { sub(/^ora_pmon_/, "", $1); print $1 }' \
               | sort -u)
    fi

    # Fallback : /etc/oratab si rien trouvé
    if [ -z "$sids" ] && [ -r /etc/oratab ]; then
        sids=$(grep -vE '^[[:space:]]*(#|$)' /etc/oratab \
               | cut -d: -f1 \
               | sort -u)
    fi

    # Filtre ASM / APEX / management
    echo "$sids" | grep -vE '^(\+ASM|APX|MGMTDB)' || true
}

# Renvoie 0 si une instance ASM tourne, 1 sinon.
detect_asm_running() {
    ps -eo args= 2>/dev/null | awk '$1 ~ /^ora_pmon_\+ASM/ { found=1; exit } END { exit !found }'
}

# Détermine si la base courante (ORACLE_SID + env oraenv'd) est un CDB.
# Renvoie 0 si CDB, 1 sinon.
is_cdb() {
    local result
    result=$(sqlplus -s -L / as sysdba <<'SQL' 2>/dev/null
SET HEADING OFF FEEDBACK OFF VERIFY OFF PAGESIZE 0
SELECT cdb FROM v$database;
EXIT;
SQL
    )
    [ "$(echo "$result" | tr -d '[:space:]')" = "YES" ]
}
