-- TITLE: Fichiers de journalisation (Redolog) — groupes et membres
SELECT
  l.group#                                       AS group_num,
  l.thread#                                      AS thread_num,
  l.sequence#                                    AS sequence_num,
  ROUND(l.bytes / 1024/1024)                     AS size_mb,
  l.members                                      AS member_count,
  l.archived,
  l.status,
  lf.member                                      AS file_path,
  lf.type
FROM v$log l
JOIN v$logfile lf ON lf.group# = l.group#
ORDER BY l.group#, lf.member
;
