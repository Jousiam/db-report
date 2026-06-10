-- TITLE: Informations système Oracle
-- Synthèse des paramètres identifiant de l'instance.
-- Porte de la version d'origine avec ajout du mode memoire (manuel / auto SGA / auto memory).
SELECT *
FROM (
  SELECT
    'Database name'                                        AS system_item,
    (SELECT value FROM v$parameter WHERE name = 'db_name') AS system_value FROM dual
  UNION ALL SELECT 'Oracle version',
    (SELECT version FROM v$instance) FROM dual
  UNION ALL SELECT 'Instance name',
    (SELECT instance_name FROM v$instance) FROM dual
  UNION ALL SELECT 'Host name',
    (SELECT host_name FROM v$instance) FROM dual
  UNION ALL SELECT 'Startup time',
    TO_CHAR((SELECT startup_time FROM v$instance), 'YYYY-MM-DD HH24:MI:SS') FROM dual
  UNION ALL SELECT 'Block size',
    (SELECT value FROM v$parameter WHERE name = 'db_block_size') || ' bytes' FROM dual
  UNION ALL SELECT 'Memory mode',
    CASE
      WHEN (SELECT TO_NUMBER(value) FROM v$parameter WHERE name = 'memory_target') > 0
        THEN 'AUTOMATIC MEMORY MANAGEMENT'
      WHEN (SELECT TO_NUMBER(value) FROM v$parameter WHERE name = 'sga_target') > 0
        THEN 'AUTO SGA + MANUAL PGA'
      ELSE 'MANUAL'
    END FROM dual
  UNION ALL SELECT 'Physical RAM',
    ROUND((SELECT value FROM v$osstat WHERE stat_name = 'PHYSICAL_MEMORY_BYTES') / 1024/1024) || ' MB' FROM dual
  UNION ALL SELECT 'Physical CPUs',
    (SELECT value FROM v$osstat WHERE stat_name = 'NUM_CPUS') || ' cores' FROM dual
  UNION ALL SELECT 'CDB ?',
    (SELECT cdb FROM v$database) FROM dual
  UNION ALL SELECT 'PDB count',
    TO_CHAR((SELECT COUNT(*) FROM v$containers WHERE con_id > 2)) FROM dual
)
;
