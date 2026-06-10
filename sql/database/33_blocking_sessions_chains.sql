-- TITLE: Chaines de blocage entre sessions — detection precoce
-- Liste chaque session bloquee avec son age. Une session bloquee plus d'1h
-- signale typiquement un probleme infra (FRA pleine, archivelog bloque, deadlock
-- non resolu) — ce qu'un audit DBA doit detecter immediatement.
SELECT
  s_blocker.sid                                            AS blocker_sid,
  s_blocker.serial#                                        AS blocker_ser,
  s_blocker.username                                       AS blocker_user,
  s_blocker.machine                                        AS blocker_host,
  s_blocker.module                                         AS blocker_module,
  s_blocked.sid                                            AS blocked_sid,
  s_blocked.username                                       AS blocked_user,
  s_blocked.event                                          AS blocked_event,
  s_blocked.seconds_in_wait                                AS wait_s,
  s_blocked.sql_id                                         AS blocked_sql_id,
  CASE
    WHEN s_blocked.seconds_in_wait > 86400  THEN 'CRITICAL: > 24h — session zombie'
    WHEN s_blocked.seconds_in_wait > 3600   THEN 'CRITICAL: > 1h — investigation requise'
    WHEN s_blocked.seconds_in_wait > 600    THEN 'WARNING: > 10min'
    WHEN s_blocked.seconds_in_wait > 60     THEN 'NOTICE: > 1min'
    ELSE 'OK'
  END                                                      AS verdict
FROM   v$session s_blocked
JOIN   v$session s_blocker ON s_blocker.sid = s_blocked.blocking_session
WHERE  s_blocked.blocking_session IS NOT NULL
ORDER BY s_blocked.seconds_in_wait DESC
FETCH FIRST 30 ROWS ONLY
;
