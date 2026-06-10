-- TITLE: Tablespaces — usage, autoextend, verdict
WITH tbs_info AS (
  SELECT
    df.tablespace_name, df.bigfile, df.contents, df.status,
    df.extent_management, df.allocation_type, df.segment_space_management,
    SUM(d.bytes)                                AS allocated_bytes,
    SUM(CASE WHEN d.autoextensible = 'YES'
             THEN GREATEST(d.maxbytes, d.bytes)
             ELSE d.bytes END)                  AS max_bytes,
    MAX(d.autoextensible)                       AS autoextend
  FROM dba_tablespaces df
  JOIN dba_data_files d ON d.tablespace_name = df.tablespace_name
  WHERE df.contents != 'TEMPORARY'
  GROUP BY df.tablespace_name, df.bigfile, df.contents, df.status,
           df.extent_management, df.allocation_type, df.segment_space_management
),
tbs_used AS (
  SELECT tablespace_name, SUM(bytes) AS used_bytes
  FROM dba_segments GROUP BY tablespace_name
)
SELECT
  ti.tablespace_name,
  ti.contents,
  ti.status,
  ti.autoextend,
  ROUND(ti.allocated_bytes / 1024/1024)                                 AS alloc_mb,
  ROUND(NVL(tu.used_bytes, 0) / 1024/1024)                              AS used_mb,
  ROUND(NVL(tu.used_bytes, 0) * 100 / ti.allocated_bytes, 1)            AS used_pct_alloc,
  ROUND(NVL(tu.used_bytes, 0) * 100 / ti.max_bytes, 1)                  AS used_pct_max,
  ROUND(ti.max_bytes / 1024/1024)                                       AS max_mb,
  CASE
    WHEN ti.status = 'OFFLINE'                                          THEN 'OFFLINE'
    -- Tablespaces critiques (SYSAUX, SYSTEM, UNDO) ont des seuils plus stricts
    WHEN ti.tablespace_name IN ('SYSAUX','SYSTEM')
         AND ti.autoextend = 'NO'
         AND NVL(tu.used_bytes,0)*100/ti.allocated_bytes > 85           THEN 'CRITICAL: ' || ti.tablespace_name || ' sans autoextend > 85% — bloque l''instance imminent'
    WHEN ti.tablespace_name IN ('SYSAUX','SYSTEM')
         AND NVL(tu.used_bytes,0)*100/ti.max_bytes > 90                 THEN 'CRITICAL: ' || ti.tablespace_name || ' > 90% du max'
    WHEN ti.contents = 'UNDO'
         AND NVL(tu.used_bytes,0)*100/ti.max_bytes > 90                 THEN 'CRITICAL: UNDO > 90% — ORA-30036 imminent'
    WHEN NVL(tu.used_bytes, 0) * 100 / ti.max_bytes > 95                THEN 'CRITICAL: > 95% of max'
    WHEN NVL(tu.used_bytes, 0) * 100 / ti.max_bytes > 85                THEN 'WARNING: > 85% of max'
    WHEN ti.autoextend = 'NO'
         AND NVL(tu.used_bytes, 0) * 100 / ti.allocated_bytes > 80      THEN 'WARNING: no autoextend & > 80%'
    ELSE 'OK'
  END                                                                    AS verdict
FROM tbs_info ti
LEFT JOIN tbs_used tu ON tu.tablespace_name = ti.tablespace_name
ORDER BY used_pct_max DESC NULLS LAST
;
