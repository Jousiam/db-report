-- TITLE: Taille de la base de données
-- Volumétrie globale : datafiles + tempfiles + redo logs + ASM si applicable
SELECT
  ROUND((SELECT SUM(bytes) FROM dba_data_files)            / 1024/1024/1024, 2) AS datafiles_gb,
  ROUND((SELECT NVL(SUM(bytes),0) FROM dba_temp_files)     / 1024/1024/1024, 2) AS tempfiles_gb,
  ROUND((SELECT SUM(bytes*members) FROM v$log)             / 1024/1024/1024, 2) AS redo_gb,
  ROUND((SELECT NVL(SUM(bytes),0) FROM dba_data_files)
      + (SELECT NVL(SUM(bytes),0) FROM dba_temp_files)
      + (SELECT NVL(SUM(bytes*members),0) FROM v$log), 0) / 1024/1024/1024 AS total_gb,
  ROUND((SELECT NVL(SUM(bytes),0) FROM dba_segments)       / 1024/1024/1024, 2) AS used_segments_gb,
  ROUND((SELECT NVL(SUM(bytes),0) FROM dba_free_space)     / 1024/1024/1024, 2) AS free_gb
FROM dual
;
