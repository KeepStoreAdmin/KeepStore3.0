USE `taikun`;
SELECT DATABASE() AS DatabaseSelezionato,
       CASE WHEN DATABASE()='taikun' THEN 'OK' ELSE 'STOP' END AS EsitoDatabase;
SELECT VERSION() AS MySQLVersion;
SELECT CASE WHEN COUNT(*)=1 THEN 'OK' ELSE 'STOP' END AS CanonicalRoutineCount
FROM information_schema.routines
WHERE ROUTINE_SCHEMA='taikun' AND ROUTINE_NAME='Carrello_Documento';
SELECT CASE WHEN COUNT(*)=1 AND SUM(CASE WHEN SHA2(ROUTINE_DEFINITION,256)='6689fd5206acabd453c5f631d52e08beaa4e9c6025f70fd9894034b5fd6122d2' THEN 1 ELSE 0 END)=1
       THEN 'OK' ELSE 'STOP' END AS HistoricalFingerprint
FROM information_schema.routines
WHERE ROUTINE_SCHEMA='taikun' AND ROUTINE_NAME='Carrello_Documento';
SELECT CASE WHEN COUNT(*)=19 THEN 'OK' ELSE 'STOP' END AS SignatureParameterCount
FROM information_schema.parameters
WHERE SPECIFIC_SCHEMA='taikun' AND SPECIFIC_NAME='Carrello_Documento';
SELECT SECURITY_TYPE, SQL_MODE, CHARACTER_SET_CLIENT, COLLATION_CONNECTION, DATABASE_COLLATION, ROUTINE_COMMENT,
       CASE WHEN SQL_MODE='NO_AUTO_VALUE_ON_ZERO' THEN 'OK' ELSE 'STOP' END AS HistoricalSqlMode,
       SHA2(DEFINER,256) AS DefinerSha256
FROM information_schema.routines
WHERE ROUTINE_SCHEMA='taikun' AND ROUTINE_NAME='Carrello_Documento';
SELECT CASE WHEN COUNT(*)=0 THEN 'OK' ELSE 'STOP' END AS SpecificRoutinePrivileges
FROM mysql.procs_priv WHERE Db='taikun' AND Routine_name='Carrello_Documento';
SELECT CASE WHEN COUNT(*)=1 THEN 'OK' ELSE 'STOP' END AS ExactWarehouseArticleTcIndex
FROM (
 SELECT INDEX_NAME, NON_UNIQUE,
        COUNT(*) AS ColumnCount,
        SUM(SEQ_IN_INDEX=1 AND COLUMN_NAME='MagazziniId') AS C1,
        SUM(SEQ_IN_INDEX=2 AND COLUMN_NAME='ArticoliId') AS C2,
        SUM(SEQ_IN_INDEX=3 AND COLUMN_NAME='TCid') AS C3
 FROM information_schema.statistics
 WHERE TABLE_SCHEMA='taikun' AND TABLE_NAME='articoli_giacenze'
 GROUP BY INDEX_NAME, NON_UNIQUE
 HAVING NON_UNIQUE=0 AND ColumnCount=3 AND C1=1 AND C2=1 AND C3=1
) AS ExactIndexes;
SELECT COUNT(*) AS NullTcIdRows FROM articoli_giacenze WHERE TCid IS NULL;
SELECT CASE WHEN EXISTS (SELECT 1 FROM tipodocumenti WHERE Web=1 AND ImpegnaQnt=1) THEN 'OK' ELSE 'STOP' END AS WebDocumentContract;
