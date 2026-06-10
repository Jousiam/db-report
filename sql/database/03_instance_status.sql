-- TITLE: Statut de l'instance
SELECT
  instance_name,
  host_name,
  version,
  TO_CHAR(startup_time, 'YYYY-MM-DD HH24:MI:SS')          AS startup_time,
  status,
  database_status,
  instance_role,
  archiver,
  logins,
  CASE blocked WHEN 'YES' THEN 'BLOCKED' ELSE 'OK' END    AS blocked,
  active_state
FROM v$instance
;
