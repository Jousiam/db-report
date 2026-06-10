-- TITLE: Datafiles — taille, autoextend, statut
COLUMN status        FORMAT a9
COLUMN online_status FORMAT a13
COLUMN autoextend    FORMAT a10
SELECT
  d.file_id,
  d.tablespace_name,
  d.file_name,
  d.status,
  d.online_status,
  ROUND(d.bytes      / 1024/1024)                AS current_mb,
  ROUND(d.maxbytes   / 1024/1024)                AS max_mb,
  d.autoextensible                                AS autoextend,
  ROUND(d.increment_by * t.block_size / 1024/1024, 1) AS next_increment_mb
FROM dba_data_files d
JOIN dba_tablespaces t ON t.tablespace_name = d.tablespace_name
ORDER BY d.tablespace_name, d.file_id
;
