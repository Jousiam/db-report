-- TITLE: Top 20 wait events (depuis le demarrage) — avec classification par wait_class
WITH total AS (
  SELECT SUM(time_waited_micro) AS total_micro
  FROM   v$system_event
  WHERE  wait_class != 'Idle'
)
SELECT *
FROM (
  SELECT
    e.wait_class,
    e.event,
    e.total_waits                                                       AS waits,
    ROUND(e.time_waited_micro / 1000000)                                AS time_s,
    ROUND(e.average_wait_fg, 2)                                         AS avg_ms,
    ROUND(e.time_waited_micro * 100 / NULLIF(t.total_micro, 0), 1)      AS pct_of_total,
    CASE
      WHEN e.wait_class = 'Configuration'
           AND e.time_waited_micro * 100 / NULLIF(t.total_micro,0) > 10  THEN 'CRITICAL: Configuration > 10% — FRA/archivage/log_buffer en souffrance'
      WHEN e.wait_class = 'Concurrency'
           AND e.time_waited_micro * 100 / NULLIF(t.total_micro,0) > 20  THEN 'CRITICAL: Concurrency > 20% — contention applicative ou blocage chronique'
      WHEN e.wait_class = 'Cluster'
           AND e.time_waited_micro * 100 / NULLIF(t.total_micro,0) > 15  THEN 'WARNING: Cluster (RAC) interconnect en souffrance'
      WHEN e.wait_class = 'User I/O'
           AND e.time_waited_micro * 100 / NULLIF(t.total_micro,0) > 50  THEN 'WARNING: User I/O domine — indexation/buffer cache a revoir'
      WHEN e.wait_class = 'Application'
           AND e.time_waited_micro * 100 / NULLIF(t.total_micro,0) > 15  THEN 'WARNING: Application (locks applicatifs)'
      WHEN e.event IN ('log file switch (archiving needed)',
                       'log file switch completion',
                       'log file sync')
           AND e.time_waited_micro * 100 / NULLIF(t.total_micro,0) > 5   THEN 'WARNING: redo/archive en souffrance'
      WHEN e.average_wait_fg > 100                                       THEN 'NOTICE: avg_ms > 100 — latence elevee'
      ELSE 'OK'
    END                                                                  AS verdict
  FROM v$system_event e, total t
  WHERE e.wait_class != 'Idle'
    AND e.total_waits > 0
  ORDER BY e.time_waited_micro DESC
)
WHERE ROWNUM <= 20
;
