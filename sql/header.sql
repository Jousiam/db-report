-- En-tête sqlplus : préambule chargé avant chaque requête.
-- Active la sortie HTML native de sqlplus et masque tout le bruit (prompt,
-- compteurs, écho de la requête). Le résultat est une <table> HTML propre
-- que l'orchestrateur encapsule ensuite dans un <section>.

SET MARKUP HTML ON SPOOL ON HEAD '' BODY '' TABLE '' ENTMAP ON PREFORMAT OFF
SET HEADING ON
SET FEEDBACK OFF
SET VERIFY OFF
SET ECHO OFF
SET TIMING OFF
SET TIME OFF
SET TRIMOUT ON
SET TRIMSPOOL ON
SET PAGESIZE 50000
SET LINESIZE 32767
SET LONG 100000
SET LONGCHUNKSIZE 100000
SET SERVEROUTPUT OFF

ALTER SESSION SET NLS_DATE_FORMAT       = 'YYYY-MM-DD HH24:MI:SS';
ALTER SESSION SET NLS_TIMESTAMP_FORMAT  = 'YYYY-MM-DD HH24:MI:SS.FF';
ALTER SESSION SET NLS_NUMERIC_CHARACTERS = '. ';

-- CDB awareness — APPROCHE CORRECTE :
-- On vérifie d'abord v$database.cdb DANS un bloc PL/SQL anonyme, et on ne
-- déclenche l'ALTER que si on est effectivement sur une CDB. WHEN OTHERS THEN
-- NULL avale toute erreur restante sans rien écrire dans la sortie sqlplus.
--
-- Pourquoi PAS WHENEVER SQLERROR CONTINUE : ça empêche bien le script de
-- s'arrêter, mais le message ORA-65090 reste écrit dans la sortie, ce qui
-- pollue ensuite la détection d'erreur de l'orchestrateur.
BEGIN
  FOR r IN (SELECT cdb FROM v$database) LOOP
    IF r.cdb = 'YES' THEN
      EXECUTE IMMEDIATE 'ALTER SESSION SET CONTAINER = CDB$ROOT';
    END IF;
  END LOOP;
EXCEPTION
  WHEN OTHERS THEN NULL;
END;
/

