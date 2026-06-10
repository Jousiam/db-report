-- TITLE: Taille des objets par schéma (Mo)
SELECT
  owner                                           AS schema_name,
  segment_type,
  COUNT(*)                                        AS object_count,
  ROUND(SUM(bytes) / 1024/1024)                   AS size_mb,
  ROUND(SUM(bytes) / 1024/1024/1024, 2)           AS size_gb
FROM dba_segments
WHERE owner NOT IN ('SYS', 'SYSTEM', 'OUTLN', 'DBSNMP', 'APPQOSSYS',
                    'XDB', 'WMSYS', 'EXFSYS', 'MDSYS', 'CTXSYS',
                    'ORDDATA', 'ORDSYS', 'OLAPSYS', 'AUDSYS', 'GSMADMIN_INTERNAL',
                    'OJVMSYS', 'DVF', 'DVSYS', 'LBACSYS', 'REMOTE_SCHEDULER_AGENT')
GROUP BY owner, segment_type
HAVING SUM(bytes) > 1024*1024   -- > 1 MB
ORDER BY SUM(bytes) DESC
;
