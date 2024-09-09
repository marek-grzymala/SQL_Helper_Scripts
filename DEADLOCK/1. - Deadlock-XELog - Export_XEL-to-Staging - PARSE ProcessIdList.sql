DECLARE @timestamp            DATETIMEOFFSET
      , @counter              INT           = 1
      , @deadlock_id          BIGINT
      , @object_id            BIGINT
      , @associated_object_id DECIMAL(20, 0)
      , @xml_report           XML;

DECLARE @ProcessList TABLE ( [DeadlockId] BIGINT, [ProcessId] VARCHAR(50), [SPID] INT, [SpName] NVARCHAR(256), [IsVictim] BIT )

DECLARE [xml_report_cursor] CURSOR FOR
SELECT 
     COALESCE([deadlock_id], ROW_NUMBER() OVER (PARTITION BY NULL ORDER BY [deadlock_timestamp])) AS [deadlock_id]
   , CAST([xml_report] AS XML) AS [xml_report]
FROM [dbo].[DeadlockStaging]
--WHERE [deadlock_timestamp] = '2024-08-13 07:50:38.0490000 +00:00';

OPEN [xml_report_cursor];
FETCH NEXT FROM [xml_report_cursor]
INTO @deadlock_id, @xml_report;
WHILE @@FETCH_STATUS = 0
BEGIN
    
    INSERT INTO @ProcessList ([DeadlockId], [ProcessId], [SPID], [SpName], [IsVictim])
    SELECT @deadlock_id, Deadlock.Process.value('@id', 'varchar(50)') AS [ProcessId]
           , [Deadlock].[Process].value('@spid', 'INT') AS [SPID]
           , [ExecutionStack].[Frame].value('@procname', 'NVARCHAR(255)') AS [SpName]
           , CASE WHEN Deadlock.Process.value('@id', 'varchar(50)') = @xml_report.value('/deadlock[1]/victim-list[1]/victimProcess[1]/@id', 'varchar(50)') THEN 1 ELSE 0 END AS [IsVictim]
    
    FROM   @xml_report.nodes('/deadlock/process-list/process') AS [Deadlock]([Process])
    CROSS APPLY [Process].nodes('executionStack/frame') AS [ExecutionStack]([Frame])
    --WHERE [ExecutionStack].[Frame].value('@procname', 'NVARCHAR(255)') <> 'adhoc';

    FETCH NEXT FROM [xml_report_cursor]
    INTO @deadlock_id, @xml_report;
END;

CLOSE [xml_report_cursor];
DEALLOCATE [xml_report_cursor];

SELECT * FROM @ProcessList

/*
CROSS APPLY        
    DeadlockDataSource.nodes('//deadlock/victim-list/victimProcess') AS VictimsInfos (VictimsLst)


SELECT 
    p.process.value('@spid', 'INT') AS spid,
    f.frame.value('@procname', 'NVARCHAR(255)') AS procname
FROM 
    dbo.DeadlockStaging ds
CROSS APPLY 
    ds.xml_report.nodes('/deadlock/process-list/process') AS p(process)
CROSS APPLY 
    p.process.nodes('executionStack/frame') AS f(frame);
*/
