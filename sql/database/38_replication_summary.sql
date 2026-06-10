-- TITLE: Replication & haute disponibilite — synthese
-- Vue consolidee qui repond en une seule section a la question :
-- "cette base est-elle repliquee, dans quel sens, et l'etat est-il sain ?"
-- Pour chaque mecanisme (Data Guard, Dbvisit, GoldenGate, Streams) on emet
-- UNE ligne resume avec status NOT_CONFIGURED / ACTIVE / DEGRADED / ERROR.
WITH
  -- 1. Data Guard : detection via v$database (toujours present)
  dg AS (
    SELECT
      database_role,
      protection_mode,
      protection_level,
      open_mode,
      switchover_status,
      dataguard_broker
    FROM v$database
  ),
  -- 2. Dbvisit Standby : detection via presence du user
  dbv AS (
    SELECT COUNT(*) AS installed
    FROM   dba_users
    WHERE  username IN ('DBVISIT','DBVSYS','DBVCTL')
  ),
  -- 3. GoldenGate : detection FIABLE via dba_capture (replicat actif), pas juste le user
  ogg AS (
    SELECT
      (SELECT COUNT(*) FROM dba_capture)                AS capture_count,
      (SELECT COUNT(*) FROM dba_apply WHERE status = 'ENABLED') AS apply_count
    FROM dual
  ),
  -- 4. Streams (deprecated mais peut etre encore en service)
  strm AS (
    SELECT COUNT(*) AS active_capture FROM v$streams_capture WHERE state = 'CAPTURING CHANGES'
  )
SELECT
  'Data Guard'                                                          AS mecanisme,
  CASE
    WHEN dg.database_role = 'PRIMARY'
         AND dg.dataguard_broker = 'DISABLED'
         AND dg.protection_mode = 'MAXIMUM PERFORMANCE'
         AND dg.switchover_status = 'NOT ALLOWED'                       THEN 'NOT_CONFIGURED'
    WHEN dg.database_role LIKE '%STANDBY%'                              THEN 'ACTIVE (standby)'
    WHEN dg.database_role = 'PRIMARY'
         AND dg.dataguard_broker = 'ENABLED'                            THEN 'ACTIVE (primary, broker)'
    WHEN dg.database_role = 'PRIMARY'
         AND dg.protection_level != dg.protection_mode                  THEN 'DEGRADED'
    WHEN dg.database_role = 'PRIMARY'                                   THEN 'ACTIVE (primary)'
    ELSE 'UNKNOWN'
  END                                                                    AS status,
  'role=' || dg.database_role
    || ', mode=' || dg.protection_mode
    || ', broker=' || dg.dataguard_broker                               AS details,
  CASE
    WHEN dg.database_role = 'PRIMARY'
         AND dg.dataguard_broker = 'DISABLED'
         AND dg.protection_mode = 'MAXIMUM PERFORMANCE'                 THEN 'OK: pas de Data Guard configure'
    WHEN dg.database_role LIKE '%STANDBY%'                              THEN 'OK: standby actif — voir section apply lag pour le detail'
    WHEN dg.database_role = 'PRIMARY' AND dg.dataguard_broker = 'ENABLED' THEN 'OK: primary avec broker — voir section apply lag'
    WHEN dg.database_role = 'PRIMARY' AND dg.protection_level != dg.protection_mode THEN 'CRITICAL: protection_level differe de protection_mode'
    ELSE 'OK'
  END                                                                    AS verdict
FROM dg
UNION ALL
SELECT
  'Dbvisit Standby',
  CASE WHEN dbv.installed > 0 THEN 'INSTALLED' ELSE 'NOT_CONFIGURED' END,
  CASE WHEN dbv.installed > 0
       THEN 'user Dbvisit detecte — verifier le lag via "dbvctl -d <DDC> -i" en CLI'
       ELSE 'aucun user DBVISIT/DBVSYS/DBVCTL trouve'
  END,
  CASE WHEN dbv.installed > 0 THEN 'OK: voir log dbvctl pour le lag exact' ELSE 'OK: Dbvisit non installe' END
FROM dbv
UNION ALL
SELECT
  'GoldenGate',
  CASE
    WHEN ogg.apply_count > 0                                            THEN 'ACTIVE (apply)'
    WHEN ogg.capture_count > 0                                          THEN 'ACTIVE (capture)'
    ELSE 'NOT_CONFIGURED'
  END,
  'captures=' || ogg.capture_count || ', applies=' || ogg.apply_count,
  CASE
    WHEN ogg.apply_count > 0 OR ogg.capture_count > 0                   THEN 'OK: GoldenGate actif — voir ggsci pour le detail'
    ELSE 'OK: pas de GoldenGate configure'
  END
FROM ogg
UNION ALL
SELECT
  'Streams',
  CASE WHEN strm.active_capture > 0 THEN 'ACTIVE' ELSE 'NOT_CONFIGURED' END,
  'captures actives=' || strm.active_capture,
  CASE
    WHEN strm.active_capture > 0                                        THEN 'WARNING: Streams deprecated depuis Oracle 19c — migrer vers GoldenGate'
    ELSE 'OK: pas de Streams configure'
  END
FROM strm
;
