-- TITLE: Sessions utilisateur actives depuis > 10 minutes
-- Une session USER active depuis > 1h est probablement bloquee ou en runaway.
-- Ce filtre exclut les sessions Oracle internes (background processes) et
-- les sessions inactives.
SELECT
  s.sid,
  s.serial#                                       AS serial_num,
  s.username,
  s.machine,
  s.osuser,
  s.module,
  s.program,
  s.status,
  s.wait_class,
  s.event,
  ROUND(s.last_call_et / 60, 1)                   AS minutes_active,
  s.sql_id,
  CASE
    WHEN s.last_call_et > 86400  THEN 'CRITICAL: > 24h — kill candidate'
    WHEN s.last_call_et > 3600   THEN 'CRITICAL: > 1h — investigation'
    WHEN s.last_call_et > 1800   THEN 'WARNING: > 30min'
    ELSE 'NOTICE'
  END                                             AS verdict
FROM v$session s
WHERE s.type = 'USER'
  AND s.status = 'ACTIVE'
  AND s.username IS NOT NULL
  AND s.last_call_et > 600   -- > 10 minutes
ORDER BY s.last_call_et DESC
FETCH FIRST 30 ROWS ONLY
;
