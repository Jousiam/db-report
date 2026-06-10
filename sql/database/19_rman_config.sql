-- TITLE: Configuration RMAN (parametres modifies + bonnes pratiques)
WITH cfg AS (
  SELECT conf#, name, value FROM v$rman_configuration
),
all_settings AS (
  SELECT 'RETENTION POLICY'                AS check_name FROM dual UNION ALL
  SELECT 'CONTROLFILE AUTOBACKUP'          FROM dual UNION ALL
  SELECT 'ARCHIVELOG DELETION POLICY'      FROM dual UNION ALL
  SELECT 'BACKUP OPTIMIZATION'             FROM dual UNION ALL
  SELECT 'DEVICE TYPE'                     FROM dual
)
SELECT
  s.check_name,
  NVL(MAX(c.value), '(default / non configure)')                                  AS current_value,
  CASE
    WHEN s.check_name = 'CONTROLFILE AUTOBACKUP'
         AND NVL(MAX(c.value),'OFF') = 'OFF'                                       THEN 'WARNING: CONTROLFILE AUTOBACKUP OFF — backup ctlfile incomplet'
    WHEN s.check_name = 'ARCHIVELOG DELETION POLICY'
         AND NVL(MAX(c.value),'NONE') = 'NONE'                                     THEN 'WARNING: pas de politique de purge archives — FRA va saturer'
    WHEN s.check_name = 'RETENTION POLICY'
         AND NVL(MAX(c.value),'NONE') = 'NONE'                                     THEN 'WARNING: pas de RETENTION POLICY — rotation backups absente'
    WHEN s.check_name = 'BACKUP OPTIMIZATION'
         AND NVL(MAX(c.value),'OFF') = 'OFF'                                       THEN 'NOTICE: BACKUP OPTIMIZATION OFF — backups redondants'
    ELSE 'OK'
  END                                                                              AS verdict
FROM all_settings s
LEFT JOIN cfg c ON UPPER(c.name) = s.check_name
GROUP BY s.check_name
ORDER BY s.check_name
;
