USE [tempdb];
GO

--IF OBJECT_ID('#sqlperf_logspace') IS NOT NULL
--	BEGIN
--	PRINT 'deleting: sqlperf_logspace';
--    DROP TABLE #sqlperf_logspace;
--	END
--GO

--IF OBJECT_ID('#master_sysaltfiles') IS NOT NULL 
--	BEGIN
--	PRINT 'deleting: sqlperf_logspace';
--    DROP TABLE #master_sysaltfiles;
--	END
--GO

CREATE TABLE #sqlperf_logspace
	( [dbname] sysname
	,logSizeMB float
	,logSpaceUsedPct float
	,Status int);

CREATE TABLE #master_sysaltfiles
	( [dbname] nvarchar(max) null
	,FILE_LOGICAL_NAME nvarchar(max) null
	,FILE_PHYS_LOCATION nvarchar(max) null
	,SIZE int
	,SIZE_IN_MB float
	,RECOVERY_MODEL sql_variant);

INSERT INTO #sqlperf_logspace
EXEC ('DBCC SQLPERF(LOGSPACE);')

INSERT INTO #master_sysaltfiles
SELECT 
	d.name AS DATABASE_NAME
	, f.name AS FILE_LOGICAL_NAME
	, f.filename AS FILE_PHYS_LOCATION
	, f.size
	, f.size as result_in_MB
	, databasepropertyex(d.name, 'Recovery') as RECOVERY_MODEL
	FROM master..sysaltfiles f 
	INNER JOIN master.dbo.sysdatabases d
	ON (f.dbid = d.dbid) WHERE f.groupid = 0;

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
LEFT JOIN #master_sysaltfiles m
ON l.dbname = m.dbname
--WHERE m.RECOVERY_MODEL = 'FULL'
ORDER BY l.logSpaceUsedPct DESC


DROP TABLE #sqlperf_logspace;
DROP TABLE #master_sysaltfiles;
