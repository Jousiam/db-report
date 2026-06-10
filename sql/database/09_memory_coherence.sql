-- TITLE: Cohérence mémoire (SGA + PGA_LIMIT vs RAM physique)
-- NOUVEAU vs version d'origine : check absent de tous les scripts DBA generic.
-- Détecte l'incoherence qui cause des ORA-00700 [pga physmem limit] et
-- des risques OOM. Alerte si la somme depasse 80% de la RAM physique.
WITH mem AS (
  SELECT
    (SELECT TO_NUMBER(value) FROM v$parameter WHERE name = 'sga_max_size')          AS sga_bytes,
    (SELECT TO_NUMBER(value) FROM v$parameter WHERE name = 'pga_aggregate_limit')   AS pga_limit_bytes,
    (SELECT TO_NUMBER(value) FROM v$parameter WHERE name = 'pga_aggregate_target')  AS pga_target_bytes,
    (SELECT value FROM v$osstat WHERE stat_name = 'PHYSICAL_MEMORY_BYTES')          AS ram_bytes
  FROM dual
)
SELECT
  ROUND(ram_bytes / 1024/1024)                                          AS ram_mb,
  ROUND(sga_bytes / 1024/1024)                                          AS sga_mb,
  ROUND(pga_target_bytes / 1024/1024)                                   AS pga_target_mb,
  ROUND(pga_limit_bytes / 1024/1024)                                    AS pga_limit_mb,
  ROUND((sga_bytes + pga_limit_bytes) / 1024/1024)                      AS total_ceiling_mb,
  ROUND((sga_bytes + pga_limit_bytes) / ram_bytes * 100, 1)             AS ceiling_pct_of_ram,
  CASE
    WHEN (sga_bytes + pga_limit_bytes) > ram_bytes
      THEN 'CRITICAL: SGA + PGA_LIMIT dépasse la RAM physique'
    WHEN (sga_bytes + pga_limit_bytes) > ram_bytes * 0.8
      THEN 'WARNING: > 80% RAM, risque OOM sous charge'
    WHEN (sga_bytes + pga_limit_bytes) > ram_bytes * 0.7
      THEN 'NOTICE: > 70% RAM, surveiller'
    ELSE 'OK'
  END                                                                   AS verdict
FROM mem
;
