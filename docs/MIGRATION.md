# Guide de migration depuis Yacine31/db_report

Ce projet ne porte pas l'intégralité des ~50 scripts SQL de la version d'origine. Pour ajouter
les autres au fur et à mesure, voici la marche à suivre.

## 1. Reprendre une requête d'origine

Récupère le SQL brut depuis le repo d'origine. Par exemple
`sql/05_tablespace_details.sql` de la version d'origine donne quelque chose comme :

```sql
COL tablespace_name FORMAT a30
SELECT tablespace_name, status, contents, ...
FROM dba_tablespaces;
```

## 2. Nettoyer les commandes SQL*Plus

`COL`, `SET PAGESIZE`, `SPOOL`, `PROMPT`, `BREAK`, etc. sont des commandes
**SQL*Plus**, pas des commandes SQL. python-oracledb les rejettera. Supprime-les
toutes — la mise en forme est faite côté `report_builder.py`.

## 3. Ajouter le marqueur de titre

En première ligne, ajoute :
```sql
-- TITLE: Tablespaces : usage, autoextend, free space
```

Le runner le lit pour générer le titre de section. Sinon, le nom du fichier
(sans le préfixe numérique) est utilisé.

## 4. Une seule requête par fichier

Le runner exécute UNE requête par fichier. Si tu portes un script d'origine qui
en contient plusieurs, sépare-les en plusieurs fichiers : `08_tablespaces.sql`,
`09_datafiles.sql`, etc.

## 5. Préfixer le nom du fichier par un numéro

Le runner trie les fichiers par ordre alphabétique, donc le numéro contrôle
l'ordre des sections dans le rapport. Garde une numérotation cohérente :

- 01-09 : système / instance / paramètres
- 10-19 : mémoire et performance
- 20-29 : stockage (tablespaces, datafiles, FRA)
- 30-39 : sécurité (users, profiles, audit)
- 40-49 : sauvegardes (RMAN, archive log)
- 50-59 : maintenance (jobs, auto-tasks)
- 60-69 : sessions, locks

## 6. Améliorer pendant le portage

Avant de copier-coller, demande-toi :

- **Le format des dates** : passer en `YYYY-MM-DD HH24:MI:SS` partout.
- **L'ajout d'un diagnostic** : la requête peut-elle inclure une colonne `verdict`
  qui synthétise OK / WARNING / BAD à partir de seuils ? C'est ce qui transforme
  un dump de chiffres en finding actionnable.
- **CDB-awareness** : sur un CDB, ajouter `con_id` (et joindre avec
  `v$containers` pour le nom) si la métrique varie par container.
- **Le row limit** : `FETCH FIRST N ROWS ONLY` plutôt que `WHERE rownum <= N`
  (syntaxe 12c+, plus claire et compose avec ORDER BY).

## 7. Tester

Avant de committer, lance le rapport sur une base de dev :
```bash
db-report run --sid DEV --format html
```
Vérifie que la section apparaît, que les colonnes sont correctes, et que le
contenu est lisible dans le HTML modernisé.

## Mapping des fichiers d'origine → nouveaux

| Origine `sql/*.sql`                  | Nouveau                                          | Statut       |
| ----------------------------------- | ------------------------------------------------ | ------------ |
| `01_System_Information.sql`         | `database/01_system_info.sql`                    | ✓ Porté      |
| `02_DB_size.sql`                    | `database/08_db_size.sql`                        | À porter     |
| `03_Database_Instance_Status.sql`   | `database/09_instance_status.sql`                | À porter     |
| `04_Database_Version.sql`           | (fusionné dans `01_system_info.sql`)             | ✓ Inutile    |
| `05_Parameters.sql`                 | `database/10_parameters.sql`                     | À porter     |
| `06_NLS_Parameters.sql`             | `database/11_nls.sql`                            | À porter     |
| `07_DBA_Registry.sql`               | `database/12_features.sql`                       | À porter     |
| `08_Resource_Limit.sql`             | `database/13_resource_limits.sql`                | À porter     |
| `09_Memory_Information.sql`         | (couvert par 02 + 03 + 04 + 05, plus complet)    | ✓ Inutile    |
| `10_Memory_Resize.sql`              | `database/14_memory_resize_history.sql`          | À porter     |
| `11_SGA_Advice.sql`                 | (devenu `database/04_shared_pool_health.sql`)    | ✓ Amélioré   |
| `12_PGA_Advice.sql`                 | (devenu `database/03_pga_advice.sql`)            | ✓ Amélioré   |
| `13_Tablespaces.sql`                | `database/20_tablespaces.sql`                    | À porter     |
| `14_Datafiles.sql`                  | `database/21_datafiles.sql`                      | À porter     |
| `15_Corrupted_Blocks.sql`           | `database/22_block_corruption.sql`               | À porter     |
| `16_Redolog.sql`                    | `database/23_redo_logs.sql`                      | À porter     |
| `17_FRA.sql`                        | `database/24_fra_usage.sql`                      | À porter     |
| `18_Alert_Log_Errors.sql`           | (devenu `database/06_alert_log_errors.sql`)      | ✓ Amélioré   |
| `19_RMAN_Config.sql`                | `database/40_rman_config.sql`                    | À porter     |
| `20_RMAN_Backups.sql`               | `database/41_rman_backups.sql`                   | À porter     |
| `21_SYSAUX_Occupants.sql`           | `database/25_sysaux_occupants.sql`               | À porter     |
| `22_DBA_Users.sql`                  | `database/30_users.sql`                          | À porter     |
| `23_DBA_Profiles.sql`               | `database/31_profiles.sql`                       | À porter     |
| `24_Object_sizes.sql`               | `database/26_objects_size.sql`                   | À porter     |
| `25_Sessions_per_User.sql`          | `database/60_sessions_per_user.sql`              | À porter     |
| `26_Sessions_per_Module.sql`        | `database/61_sessions_per_module.sql`            | À porter     |
| `27_Active_Sessions.sql`            | `database/62_active_sessions.sql`                | À porter     |
| `28_Invalid_Objects.sql`            | `database/27_invalid_objects.sql`                | À porter     |
| `29_Objects_per_User.sql`           | `database/28_objects_per_user.sql`               | À porter     |
| `30_Auto_Tasks.sql`                 | `database/50_autotask_status.sql`                | À porter     |
| `31_Sessions_Cursors.sql`           | `database/63_sessions_cursors.sql`               | À porter     |
| `32_Failed_Jobs.sql`                | `database/51_failed_jobs.sql`                    | À porter     |
| `33_Table_Stats_Summary.sql`        | `database/52_table_stats.sql`                    | À porter     |
| `34_Feature_Usage.sql`              | `database/29_feature_usage.sql`                  | À porter     |
| (absent de la version d'origine)                  | `database/02_memory_coherence.sql`               | ✓ Nouveau    |
| (absent de la version d'origine)                  | `database/05_buffer_cache_advice.sql`            | ✓ Nouveau    |
| (absent de la version d'origine)                  | `database/07_top_wait_events.sql`                | ✓ Nouveau    |
