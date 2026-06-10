-- TITLE: Sessions actives (snapshot)
-- AMÉLIORÉ vs version d'origine : ajoute le wait_class et le blocking_session pour
-- repérer immédiatement les chains de blocage.
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
  s.blocking_session,
  ROUND(s.last_call_et / 60, 1)                   AS minutes_in_call,
  s.sql_id
FROM v$session s
WHERE s.type = 'USER'
  AND s.status IN ('ACTIVE', 'KILLED')
  AND s.username IS NOT NULL
ORDER BY s.blocking_session NULLS LAST, s.last_call_et DESC
;
