USE [tempdb];
GO

IF OBJECT_ID('#sqlperf_logspace') IS NOT NULL
	BEGIN
	PRINT 'deleting: sqlperf_logspace';
    DROP TABLE #sqlperf_logspace;
	END
GO

IF OBJECT_ID('#master_sysaltfiles') IS NOT NULL 
	BEGIN
	PRINT 'deleting: sqlperf_logspace';
    DROP TABLE #master_sysaltfiles;
	END
GO

CREATE TABLE #sqlperf_logspace
	( [dbname] sysname
	,logSizeMB float
	,logSpaceUsedPct float
	,Status int);

CREATE TABLE #master_sysaltfiles
	( [dbname] sysname
	,FILE_LOGICAL_NAME sysname
	,FILE_PHYS_LOCATION sysname
	,SIZE int
	,SIZE_IN_MB float
	,RECOVERY_MODEL sql_variant);

INSERT INTO #sqlperf_logspace
EXEC ('DBCC SQLPERF(LOGSPACE);')

INSERT INTO #master_sysaltfiles
EXEC ('SELECT 
	d.name AS DATABASE_NAME
	, f.name AS FILE_LOGICAL_NAME
	, f.filename AS FILE_PHYS_LOCATION
	, f.size
	, 8192.0E * f.size / 1048576.0E as result_in_MB
	, databasepropertyex(d.name, ''Recovery'') as RECOVERY_MODEL
	FROM master..sysaltfiles f 
	INNER JOIN master.dbo.sysdatabases d
	ON (f.dbid = d.dbid) WHERE f.groupid = 0;')

SELECT
 
	l.dbname													AS [DB_NAME]
	,m.FILE_LOGICAL_NAME										AS [FILE_LOGICAL_NAME]
	,m.FILE_PHYS_LOCATION										AS [FILE_PHYS_LOCATION]
	,ROUND(l.logSizeMB, 2)										AS [LOG SIZE IN MB]
	,ROUND(l.logSpaceUsedPct, 2)								AS [% LOG SPACE USED]
	,ROUND(l.logSizeMB - (logSizeMB * logSpaceUsedPct / 100),2)	AS [LOG SPACE UNUSED IN MB]
	,m.RECOVERY_MODEL
	--,l.Status
	--,m.dbname 
	--,m.SIZE
	--,m.SIZE_IN_MB

FROM #sqlperf_logspace l
INNER JOIN #master_sysaltfiles m
ON l.dbname = m.dbname
WHERE l.dbname = N'YourDbName' --m.RECOVERY_MODEL = 'FULL'
ORDER BY l.dbname, l.logSizeMB DESC; --l.logSpaceUsedPct

DROP TABLE #sqlperf_logspace;
DROP TABLE #master_sysaltfiles;


