# DB Report v2.9 — Améliorations vs db_report

## Couverture des requêtes (40 sections)

### Identité et configuration (8)
01-08 : system_info, db_size, instance_status, supplemental_logging★, init_parameters, nls_parameters, dba_registry, resource_limits

### Diagnostics mémoire (5)
09-13 : memory_coherence, pga_advice, shared_pool_health, buffer_cache_advice, memory_resize_history

### Stockage (4)
14-17 : tablespaces_usage★, datafiles, redo_logs, redo_switch_history

### Recovery / Backup (3)
18-20 : fra_usage★, rman_config★, rman_backups★

### Sécurité / Schémas (4)
21-24 : sysaux_occupants★, dba_users, dba_profiles, object_size_per_schema

### Sessions et activité (2)
25-26 : active_sessions, sessions_cursors_usage

### Maintenance (4)
27-30 : autotask_status, failed_jobs★, invalid_objects★, feature_usage★

### Diagnostic profond (7)
31-37 : alert_log_errors★, top_wait_events★, blocking_sessions_chains◆, archive_dest_status◆, long_running_sessions◆, top_sql_by_elapsed◆, index_unusable◆

### Réplication / haute disponibilité (3) ◆ REFONDU
- **38_replication_summary** ◆ Synthèse en une section : statut clair par mécanisme (NOT_CONFIGURED / ACTIVE / DEGRADED / ERROR) pour Data Guard, Dbvisit, GoldenGate, Streams. C'est la section à lire en premier pour savoir si la base est répliquée.
- **39_dataguard_lag_detail** ◆ Détails apply_lag, transport_lag, processus MRP/RFS/LNS — seulement utile si DG actif (sinon sort une ligne `NOT_CONFIGURED` propre).
- **40_dataguard_archive_gap** ◆ Détection des gaps d'archives entre primary et standby. Sort `NO_GAP` clair si aucun gap, ou `NOT_APPLICABLE` si pas un standby.

★ = verdict enrichi
◆ = section ajoutée

## Sur la section 38 — pourquoi consolider ?

Avant la refonte, on avait 5 sections séparées (DG status, DG lag, DG gap, Dbvisit, GG/Streams) — chacune sortait des données isolées dont l'absence ne signifiait rien de clair. On ne savait pas en un coup d'œil "est-ce que cette base réplique vers/depuis quelque part ?"

La section 38 répond à ça en une table à 4 lignes (une par mécanisme), avec un `status` lisible et un `verdict` actionnable. Les sections 39 et 40 restent comme **drill-down** : utiles si la section 38 dit "ACTIVE" et qu'on veut voir le lag exact.

### Détection fiable de chaque mécanisme

- **Data Guard** : `v$database` toujours présent. `dataguard_broker = ENABLED` ou `database_role LIKE '%STANDBY%'` = ACTIVE. Pour PRIMARY, on évite le faux positif "CRITICAL: protection_level différent" qui apparaît sur toutes les bases standalone en `MAXIMUM PERFORMANCE` natif.

- **Dbvisit** : `dba_users.username IN ('DBVISIT','DBVSYS','DBVCTL')`. **Pas** de query sur des tables Dbvisit (qui n'existent pas si pas installé → ORA-00942). Pour le lag exact, il faut `dbvctl -d <DDC> -i` côté shell, hors périmètre SQL.

- **GoldenGate** : détection via `dba_capture` et `dba_apply` (présence d'objets de réplication actifs), **pas** via la présence du user `GGSYS` qui existe en standard depuis Oracle 19c sur toutes les bases (faux positif).

- **Streams** : `v$streams_capture WHERE state = 'CAPTURING CHANGES'`. Streams est deprecated depuis 19c, donc si actif → WARNING (migrer vers GoldenGate).

## Philosophie des verdicts

- **OK** : valeur dans les normes
- **INFO** : information neutre (ex : "Dbvisit non installé")
- **NOTICE** : observation à connaître, pas d'action requise
- **WARNING** : situation à surveiller, action recommandée
- **CRITICAL** : action urgente, risque de panne ou de perte de données

## Résilience

- `timeout` par requête (défaut 120s, override via `-- TIMEOUT: N`)
- `NLS_LANG=AMERICAN_AMERICA.AL32UTF8` forcé pour préserver les accents
- Strip défensif des accents dans les littéraux SQL
- Détecteur d'erreur intelligent (table + avertissement si erreur non-bloquante)
- Multi-DB combiné dans un seul HTML avec sélecteur d'onglets
- Per-SID slugs uniques pour navigation TOC fiable
- CDB awareness via PL/SQL silencieux
- `<pre>` en `white-space: pre-wrap` pour que les sorties système (lscpu, df, etc.) wrappent au lieu de déborder en horizontal
