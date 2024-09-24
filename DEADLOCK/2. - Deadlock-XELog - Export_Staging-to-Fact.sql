USE [DeadlockDemo]
GO

SET NOCOUNT ON
GO

/*
DROP TABLE IF EXISTS [dbo].[DeadlockFact];
GO
CREATE TABLE [dbo].[DeadlockFact] (    
      [DeadlockID] BIGINT NOT NULL
	, [DeadlockTimeUTC] DATETIME NOT NULL
    , [TransactionTime] DATETIME NULL
    , [LastBatchStarted] DATETIME NULL
    , [LastBatchCompleted] DATETIME NULL
    , [PagelockObject] VARCHAR(200) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
    , [DeadlockObject] VARCHAR(200) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
    , [KeyLockObject] VARCHAR(200) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
    , [KeyLockIndex] VARCHAR(200) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
    , [IsVictim] INT NOT NULL
    , [Spid] INT NOT NULL
    , [ProcessID] VARCHAR(50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
    , [LogUsed] INT NULL
    , [WaitResource] VARCHAR(50) NULL
    , [WaitPageId] AS TRY_CONVERT(INT, RIGHT([WaitResource], CHARINDEX(':', REVERSE([WaitResource]))-1))
    , [WaitTime] INT NOT NULL
    , [EcId] SMALLINT NOT NULL
    , [Procedure] VARCHAR(200) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
    , [LockMode] CHAR(5) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
    , [SqlCode] NVARCHAR(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
    , [HostName] VARCHAR(20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
    , [LoginName] VARCHAR(20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
    , [InputBuffer] VARCHAR(1000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
    , [DatabaseName_1] VARCHAR(500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
    , [DatabaseName_2] VARCHAR(500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
    , [WaitResource_1] VARCHAR(500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
    , [WaitResource_2] VARCHAR(500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
    , [xml_report] XML NULL
	, CONSTRAINT [PK_DeadlockFact_DeadlockID_DeadlockTime_ProcessID] PRIMARY KEY CLUSTERED ([DeadlockID] ASC, [ProcessID] ASC, [Spid] ASC, [IsVictim] ASC)
)
GO
*/

TRUNCATE TABLE [dbo].[DeadlockFact]

DROP TABLE IF EXISTS [#DeadlockMerge]
CREATE TABLE [#DeadlockMerge] (
	 [event_name]                            NVARCHAR(MAX) NULL
	,[deadlock_timestamp]                    DATETIMEOFFSET NOT NULL
	,[resource_type]                         NVARCHAR(MAX) NULL
	,[mode]                                  NVARCHAR(MAX) NULL
	,[owner_type]                            NVARCHAR(MAX) NULL
	,[transaction_id]                        BIGINT NULL
	,[database_id]                           BIGINT NULL
	,[lockspace_workspace_id]                DECIMAL(20, 0) NULL
	,[lockspace_sub_id]                      BIGINT NULL
	,[lockspace_nest_id]                     BIGINT NULL
	,[resource_0]                            BIGINT NULL
	,[resource_1]                            BIGINT NULL
	,[resource_2]                            BIGINT NULL
	,[deadlock_id]                           BIGINT NULL
	,[object_id]                             INT NULL
	,[associated_object_id]                  DECIMAL(20, 0) NULL
	,[session_id]                            SMALLINT NULL
	,[resource_owner_type]                   NVARCHAR(MAX) NULL
	,[resource_description]                  NVARCHAR(MAX) NULL
	,[database_name]                         NVARCHAR(MAX) NULL
	,[username]                              NVARCHAR(MAX) NULL
	,[nt_username]                           NVARCHAR(MAX) NULL
	,[duration]                              DECIMAL(20, 0) NULL
	,[sql_text]                              NVARCHAR(MAX) NULL
	,[xml_report]                            XML NULL
	,[deadlock_cycle_id]                     DECIMAL(20, 0) NULL
	,[server_name]                           NVARCHAR(MAX) NULL
) ON [PRIMARY]
GO

DECLARE @timestamp            DATETIMEOFFSET      
      , @counter              INT           = 1
      , @deadlock_id          BIGINT
      , @object_id            BIGINT
      , @associated_object_id DECIMAL(20, 0)
      , @xml_report           XML
      , @rowcount             INT
      , @ErrorMessage         NVARCHAR(4000)
      , @ErrorDeadlockIds     NVARCHAR(4000)
      , @ErrorSeverityDefault INT
      , @ErrorStateDefault    INT;

DECLARE @ErrorDeadlockIdTable TABLE([DeadlockId] INT NOT NULL)
SET @ErrorSeverityDefault = 17;
SET @ErrorStateDefault = 1;

DECLARE [timestamps_cursor] CURSOR FOR
        
        SELECT DISTINCT
			   ROW_NUMBER() OVER (PARTITION BY NULL ORDER BY [deadlock_timestamp]) AS [Rn]
             , [deadlock_timestamp]
        FROM   [dbo].[DeadlockStaging]
		ORDER BY [deadlock_timestamp]
        
OPEN [timestamps_cursor]   
FETCH NEXT FROM [timestamps_cursor] INTO @deadlock_id, @timestamp
WHILE @@FETCH_STATUS = 0   
BEGIN
--------------------------------------------------------------------------
        
        TRUNCATE TABLE [#DeadlockMerge]        
        INSERT INTO [#DeadlockMerge] 
            (
                [event_name]                       
               ,[deadlock_timestamp]          
               ,[resource_type]              
               ,[mode]                       
               ,[owner_type]                 
               ,[transaction_id]             
               ,[database_id]                
               ,[lockspace_workspace_id]     
               ,[lockspace_sub_id]           
               ,[lockspace_nest_id]          
               ,[resource_0]                 
               ,[resource_1]                 
               ,[resource_2]                 
               ,[deadlock_id]                
               ,[object_id]                  
               ,[associated_object_id]       
               ,[session_id]                 
               ,[resource_owner_type]        
               ,[resource_description]       
               ,[database_name]              
               ,[username]                   
               ,[nt_username]                
               ,[duration]                   
               ,[sql_text]
               ,[xml_report]          
               ,[deadlock_cycle_id]   
               ,[server_name]         
            )

        SELECT
             [event_name]                       
            ,[deadlock_timestamp]           
            ,[resource_type]              
            ,[mode]                       
            ,[owner_type]                 
            ,[transaction_id]             
            ,[database_id]                
            ,[lockspace_workspace_id]     
            ,[lockspace_sub_id]           
            ,[lockspace_nest_id]          
            ,[resource_0]                 
            ,[resource_1]                 
            ,[resource_2]                 
            ,COALESCE([deadlock_id], @deadlock_id) AS [deadlock_id]
            ,[object_id]
            ,[associated_object_id]       
            ,[session_id]                 
            ,[resource_owner_type]        
            ,[resource_description]       
            ,[database_name]              
            ,[username]                   
            ,[nt_username]                
            ,[duration]                   
            ,[sql_text]
            ,[xml_report]          
            ,[deadlock_cycle_id]   
            ,[server_name]         
            
        FROM [dbo].[DeadlockStaging] 
        --WHERE CONVERT(DATETIME2(0), [timestamp]) = @timestamp
		WHERE [deadlock_timestamp] = @timestamp
        SELECT @rowcount = @@ROWCOUNT

        --PRINT(CONCAT(@timestamp, ' ', @counter, ' Rowcount: ', @rowcount))
        
        IF (@rowcount > 0)
        BEGIN
			DECLARE @NumOfDeadlockIds INT
			SELECT @NumOfDeadlockIds = COUNT(DISTINCT [deadlock_id]) FROM [#DeadlockMerge] WHERE [deadlock_id] IS NOT NULL
            IF (@NumOfDeadlockIds) = 1
            BEGIN
                SELECT @deadlock_id = [deadlock_id] FROM [#DeadlockMerge] WHERE deadlock_id > 0
            END
			ELSE 
			BEGIN
					DELETE FROM @ErrorDeadlockIdTable
					INSERT INTO @ErrorDeadlockIdTable([DeadlockId]) SELECT DISTINCT [deadlock_id] FROM [#DeadlockMerge] WHERE [deadlock_id] IS NOT NULL
					SELECT @ErrorDeadlockIds = STRING_AGG([DeadlockId], ',') FROM @ErrorDeadlockIdTable;
					SET @ErrorMessage = CONCAT(N'Number of deadlock_id in the [dbo].[DeadlockStaging] for the timestamp: ', @timestamp, N' = ', @NumOfDeadlockIds, ': ', @ErrorDeadlockIds)
					--RAISERROR(@ErrorMessage, @ErrorSeverityDefault, @ErrorStateDefault)
					PRINT(@ErrorMessage);
			END
            ----------------------------------------------------------------------------------------------------------
            DECLARE [xml_report_cursor] CURSOR FOR
            
                                SELECT CAST([xml_report] AS XML) 
                                FROM [dbo].[#DeadlockMerge]
                                WHERE [xml_report] IS NOT NULL

            OPEN [xml_report_cursor]   
            FETCH NEXT FROM [xml_report_cursor] INTO @xml_report  
            WHILE @@FETCH_STATUS = 0   
                    BEGIN
                            MERGE [dbo].[DeadlockFact] AS [tgt]
							USING (
                                    SELECT
                                                [DeadlockID] = COALESCE(@deadlock_id, 0),
									            [DeadlockTimeUTC] = CONVERT(DATETIME, (COALESCE(Deadlock.Process.value('@lasttranstarted', 'datetime'), Deadlock.Process.value('@lastbatchstarted', 'datetime')) AT TIME ZONE 'Pacific Standard Time') AT TIME ZONE 'UTC'),
                                                [TransactionTime] = Deadlock.Process.value('@lasttranstarted', 'datetime'),
                                                [LastBatchStarted] = Deadlock.Process.value('@lastbatchstarted', 'datetime'),
                                                [LastBatchCompleted] = Deadlock.Process.value('@lastbatchcompleted', 'datetime'),
                                                [PagelockObject] = @xml_report.value('/deadlock[1]/resource-list[1]/pagelock[1]/@objectname', 'VARCHAR(200)'),
                                                [DeadlockObject] = @xml_report.value('/deadlock[1]/resource-list[1]/objectlock[1]/@objectname', 'VARCHAR(200)'),
                                                [KeyLockObject] = @xml_report.value('/deadlock[1]/resource-list[1]/keylock[1]/@objectname', 'VARCHAR(200)'),
                                                [KeyLockIndex] = @xml_report.value('/deadlock[1]/resource-list[1]/keylock[1]/@indexname', 'VARCHAR(200)'),                                                
                                                [IsVictim] = CASE WHEN Deadlock.Process.value('@id', 'VARCHAR(50)') = [vl].[victimId] THEN 1 ELSE 0 END,
                                                [Spid] = [Deadlock].[Process].value('@spid', 'INT'),                                                 
                                                [ProcessID] = [Deadlock].Process.value('@id', 'VARCHAR(50)'),
                                                [LogUsed] = [Deadlock].[Process].value('@logused', 'INT'), 
                                                [WaitResource] = [Deadlock].[Process].value('@waitresource', 'VARCHAR(64)'),                                                
                                                [WaitTime] = [Deadlock].[Process].value('@waittime', 'INT'), 
                                                [EcId] = Deadlock.Process.value('@ecid', 'VARCHAR(50)'),
                                                [Procedure] = [ExecutionStack].[Frame].value('@procname', 'NVARCHAR(255)'),
                                                [LockMode] = Deadlock.Process.value('@lockMode', 'char(5)'),
                                                [SqlCode] = [ExecutionStack].[Frame].value('text()[1]', 'NVARCHAR(MAX)'),
                                                [HostName] = Deadlock.Process.value('@hostname', 'VARCHAR(20)'),
                                                [LoginName] = Deadlock.Process.value('@loginname', 'VARCHAR(20)'),
                                                [InputBuffer] = Deadlock.Process.value('inputbuf[1]', 'VARCHAR(1000)'),
                                                [DatabaseName_1] = Deadlock.Process.value('/deadlock[1]/process-list[1]/process[1]/@currentdbname', 'VARCHAR(500)'),
                                                [DatabaseName_2] = Deadlock.Process.value('/deadlock[1]/process-list[1]/process[2]/@currentdbname', 'VARCHAR(500)'),
                                                [WaitResource_1] = Deadlock.Process.value('/deadlock[1]/process-list[1]/process[1]/@waitresource', 'VARCHAR(500)'),
                                                [WaitResource_2] = Deadlock.Process.value('/deadlock[1]/process-list[1]/process[2]/@waitresource', 'VARCHAR(500)'),
                                                [XmReport] = @xml_report
									FROM        @xml_report.nodes('/deadlock/process-list/process') AS [Deadlock]([Process])
                                    CROSS APPLY [Process].nodes('executionStack/frame') AS [ExecutionStack]([Frame])
                                    OUTER APPLY 
                                    (
                                        SELECT  [Victim].[victimProcess].value('@id', 'VARCHAR(50)') AS [victimId]
                                        FROM    @xml_report.nodes('/deadlock/victim-list/victimProcess') AS [Victim]([victimProcess])
                                        WHERE  [Deadlock].Process.value('@id', 'VARCHAR(50)') = [Victim].[victimProcess].value('@id', 'VARCHAR(50)')
                                    ) AS [vl]
                                    /*
                                    OUTER APPLY 
                                    (
                                        SELECT  [Owner].[ownerProcess].value('@id', 'VARCHAR(50)') AS [victimId]
                                        FROM    @xml_report.nodes('/deadlock/resource-list/pagelock/owner-list/owner') AS [Owner]([ownerProcess])
                                        WHERE  [Deadlock].Process.value('@id', 'VARCHAR(50)') = [Owner].[ownerProcess].value('@id', 'VARCHAR(50)')
                                    ) AS [rl]
                                    */
                                    WHERE [ExecutionStack].[Frame].value('@procname', 'NVARCHAR(255)') <> 'adhoc'
                            
                                    ) AS [src]
								            ON (    tgt.[DeadlockID]        = src.[DeadlockID]
								            	AND tgt.[ProcessID]         = src.[ProcessID]
                                                AND tgt.[Spid]              = src.[Spid]
								            	AND tgt.[IsVictim]          = src.[IsVictim]
                                               )
								WHEN MATCHED THEN
								UPDATE SET
						    		   tgt.[DeadlockTimeUTC]        = src.[DeadlockTimeUTC]
						    		 , tgt.[TransactionTime]        = src.[TransactionTime]
						    		 , tgt.[LastBatchStarted]		= src.[LastBatchStarted]
						    		 , tgt.[LastBatchCompleted]     = src.[LastBatchCompleted]
						    		 , tgt.[PagelockObject]			= src.[PagelockObject]
						    		 , tgt.[DeadlockObject]			= src.[DeadlockObject]
						    		 , tgt.[KeyLockObject]			= src.[KeyLockObject]
						    		 , tgt.[KeyLockIndex]			= src.[KeyLockIndex]
						    		 , tgt.[IsVictim]				= src.[IsVictim]
						    		 , tgt.[Spid]				    = src.[Spid]
						    		 , tgt.[ProcessID]				= src.[ProcessID]
                                     , tgt.[EcId]				    = src.[EcId]
                                     , tgt.[LogUsed]                = src.[LogUsed]                                     
                                     , tgt.[WaitResource]           = src.[WaitResource]
                                     , tgt.[WaitTime]               = src.[WaitTime]
                                     , tgt.[Procedure]				= src.[Procedure]
						    		 , tgt.[LockMode]				= src.[LockMode]
						    		 , tgt.[SqlCode]				= src.[SqlCode]
						    		 , tgt.[HostName]				= src.[HostName]
						    		 , tgt.[LoginName]				= src.[LoginName]
						    		 , tgt.[InputBuffer]			= src.[InputBuffer]
						    		 , tgt.[DatabaseName_1]			= src.[DatabaseName_1]
						    		 , tgt.[DatabaseName_2]			= src.[DatabaseName_2]
						    		 , tgt.[WaitResource_1]			= src.[WaitResource_1]
						    		 , tgt.[WaitResource_2]			= src.[WaitResource_2]
						    		 , tgt.[xml_report]				= src.[XmReport]
								WHEN NOT MATCHED THEN
								INSERT (
								          [DeadlockID]
								        , [DeadlockTimeUTC]
								        , [TransactionTime]
								        , [LastBatchStarted]
								        , [LastBatchCompleted]
								        , [PagelockObject]
								        , [DeadlockObject]
								        , [KeyLockObject]
								        , [KeyLockIndex]
								        , [IsVictim]
                                        , [Spid]
								        , [ProcessID]
                                        , [EcId]
                                        , [LogUsed]
                                        , [WaitResource]
                                        , [WaitTime]
								        , [Procedure]
								        , [LockMode]
								        , [SqlCode]
								        , [HostName]
								        , [LoginName]
								        , [InputBuffer]
								        , [DatabaseName_1]
								        , [DatabaseName_2]
								        , [WaitResource_1]
								        , [WaitResource_2]
								        , [xml_report] )
								VALUES (
									      src.[DeadlockID]
								          , src.[DeadlockTimeUTC]
								          , src.[TransactionTime]
								          , src.[LastBatchStarted]
								          , src.[LastBatchCompleted]
								          , src.[PagelockObject]
								          , src.[DeadlockObject]
								          , src.[KeyLockObject]
								          , src.[KeyLockIndex]
								          , src.[IsVictim]
                                          , src.[Spid]
								          , src.[ProcessID]
                                          , src.[EcId]
                                          , src.[LogUsed]
                                          , src.[WaitResource]
                                          , src.[WaitTime]
								          , src.[Procedure]
								          , src.[LockMode]
								          , src.[SqlCode]
								          , src.[HostName]
								          , src.[LoginName]
								          , src.[InputBuffer]
								          , src.[DatabaseName_1]
								          , src.[DatabaseName_2]
								          , src.[WaitResource_1]
								          , src.[WaitResource_2]
								          , src.[XmReport] );                                    
                    FETCH NEXT FROM [xml_report_cursor] INTO @xml_report  
                    END   
            CLOSE [xml_report_cursor]  
            DEALLOCATE [xml_report_cursor]
            ----------------------------------------------------------------------------------------------------------
        END
        SET @counter = @counter + 1
--------------------------------------------------------------------------
    FETCH NEXT FROM [timestamps_cursor] INTO @deadlock_id, @timestamp
END   
CLOSE [timestamps_cursor]   
DEALLOCATE [timestamps_cursor]
----------------------------------


SELECT 
  [f].[DeadlockID]
, [f].[DeadlockTimeUTC]
, [f].[TransactionTime]
--, [f].[LastBatchStarted]
--, [f].[LastBatchCompleted]
--, [f].[PagelockObject]
--, [f].[DeadlockObject]
--, [f].[KeyLockObject]
--, [f].[KeyLockIndex]
, [f].[IsVictim]
, [f].[Spid]
, [f].[ProcessID]
, [f].[WaitResource]
, [f].[Procedure]
, [f].[LockMode]
, [f].[SqlCode]
, [f].[xml_report] 

FROM [dbo].[DeadlockFact] [f]
