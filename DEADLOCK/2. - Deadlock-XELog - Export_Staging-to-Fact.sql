USE [DeadlockDemo]
GO


SET NOCOUNT ON
GO

DROP TABLE IF EXISTS [dbo].[DeadlockFact];
GO

CREATE TABLE [dbo].[DeadlockFact] (    
      [DeadlockID] BIGINT NOT NULL
	, [DeadlockTime] DATETIME NOT NULL
    , [TransactionTime] DATETIME NULL
    , [LastBatchStarted] DATETIME NULL
    , [LastBatchCompleted] DATETIME NULL
    , [PagelockObject] VARCHAR(200) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
    , [DeadlockObject] VARCHAR(200) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
    , [KeyLockObject] VARCHAR(200) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
    , [KeyLockIndex] VARCHAR(200) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
    , [IsVictim] INT NOT NULL
    , [ProcessID] VARCHAR(50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
    , [Procedure] VARCHAR(200) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
    , [LockMode] CHAR(5) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
    , [SqlCode] VARCHAR(1000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
    , [HostName] VARCHAR(20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
    , [LoginName] VARCHAR(20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
    , [InputBuffer] VARCHAR(1000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
    , [DatabaseName_1] VARCHAR(500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
    , [DatabaseName_2] VARCHAR(500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
    , [WaitResource_1] VARCHAR(500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
    , [WaitResource_2] VARCHAR(500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
    , [xml_report] XML NULL
	, CONSTRAINT [PK_DeadlockFact_DeadlockID_DeadlockTime_ProcessID_IsVictim] PRIMARY KEY CLUSTERED ([DeadlockID] ASC, [DeadlockTime] ASC, [ProcessID] ASC, [IsVictim] ASC)
)
GO


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
			   [deadlock_timestamp]
        FROM   [dbo].[DeadlockStaging]
		ORDER BY [deadlock_timestamp]
        
OPEN [timestamps_cursor]   
FETCH NEXT FROM [timestamps_cursor] INTO @timestamp
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
            
        FROM [dbo].[DeadlockStaging] 
        --WHERE CONVERT(DATETIME2(0), [timestamp]) = @timestamp
		WHERE [deadlock_timestamp] = @timestamp
        SELECT @rowcount = @@ROWCOUNT

        PRINT(CONCAT(@timestamp, ' ', @counter, ' Rowcount: ', @rowcount))
        
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
									            [DeadlockTime] = COALESCE(Deadlock.Process.value('@lasttranstarted', 'datetime'), Deadlock.Process.value('@lastbatchstarted', 'datetime')),
                                                [TransactionTime] = Deadlock.Process.value('@lasttranstarted', 'datetime'),
                                                [LastBatchStarted] = Deadlock.Process.value('@lastbatchstarted', 'datetime'),
                                                [LastBatchCompleted] = Deadlock.Process.value('@lastbatchcompleted', 'datetime'),
                                                [PagelockObject] = @xml_report.value('/deadlock[1]/resource-list[1]/pagelock[1]/@objectname', 'varchar(200)'),
                                                [DeadlockObject] = @xml_report.value('/deadlock[1]/resource-list[1]/objectlock[1]/@objectname', 'varchar(200)'),
                                                [KeyLockObject] = @xml_report.value('/deadlock[1]/resource-list[1]/keylock[1]/@objectname', 'varchar(200)'),
                                                [KeyLockIndex] = @xml_report.value('/deadlock[1]/resource-list[1]/keylock[1]/@indexname', 'varchar(200)'),
                                                [IsVictim] = CASE WHEN Deadlock.Process.value('@id', 'varchar(50)') = @xml_report.value('/deadlock[1]/victim-list[1]/victimProcess[1]/@id', 'varchar(50)') THEN 1 ELSE 0 END,
                                                [ProcessID] = Deadlock.Process.value('@id', 'varchar(50)'),
                                                [Procedure] = Deadlock.Process.value('executionStack[1]/frame[1]/@procname[1]', 'varchar(200)'),
                                                [LockMode] = Deadlock.Process.value('@lockMode', 'char(5)'),
                                                [SqlCode] = Deadlock.Process.value('executionStack[1]/frame[1]', 'varchar(1000)'),
                                                [HostName] = Deadlock.Process.value('@hostname', 'varchar(20)'),
                                                [LoginName] = Deadlock.Process.value('@loginname', 'varchar(20)'),
                                                [InputBuffer] = Deadlock.Process.value('inputbuf[1]', 'varchar(1000)'),
                                                [DatabaseName_1] = Deadlock.Process.value('/deadlock[1]/process-list[1]/process[1]/@currentdbname', 'varchar(500)'),
                                                [DatabaseName_2] = Deadlock.Process.value('/deadlock[1]/process-list[1]/process[2]/@currentdbname', 'varchar(500)'),
                                                [WaitResource_1] = Deadlock.Process.value('/deadlock[1]/process-list[1]/process[1]/@waitresource', 'varchar(500)'),
                                                [WaitResource_2] = Deadlock.Process.value('/deadlock[1]/process-list[1]/process[2]/@waitresource', 'varchar(500)'),
                                                [XmReport] = @xml_report
									FROM        @xml_report.nodes('/deadlock/process-list/process') AS [Deadlock]([Process])) AS [src]
								            ON (    tgt.[DeadlockID]   = src.[DeadlockID]
								            	AND tgt.[DeadlockTime] = src.[DeadlockTime]
								            	AND tgt.[ProcessID]    = src.[ProcessID]
								            	AND tgt.[IsVictim]     = src.[IsVictim]
								)
								WHEN MATCHED THEN
								UPDATE SET
						    		   tgt.[DeadlockTime]           = src.[DeadlockTime]
						    		 , tgt.[TransactionTime]        = src.[TransactionTime]
						    		 , tgt.[LastBatchStarted]		= src.[LastBatchStarted]
						    		 , tgt.[LastBatchCompleted]     = src.[LastBatchCompleted]
						    		 , tgt.[PagelockObject]			= src.[PagelockObject]
						    		 , tgt.[DeadlockObject]			= src.[DeadlockObject]
						    		 , tgt.[KeyLockObject]			= src.[KeyLockObject]
						    		 , tgt.[KeyLockIndex]			= src.[KeyLockIndex]
						    	--	 , tgt.[IsVictim]				= src.[IsVictim]
						    	--	 , tgt.[ProcessID]				= src.[ProcessID]
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
								        , [DeadlockTime]
								        , [TransactionTime]
								        , [LastBatchStarted]
								        , [LastBatchCompleted]
								        , [PagelockObject]
								        , [DeadlockObject]
								        , [KeyLockObject]
								        , [KeyLockIndex]
								        , [IsVictim]
								        , [ProcessID]
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
								          , src.[DeadlockTime]
								          , src.[TransactionTime]
								          , src.[LastBatchStarted]
								          , src.[LastBatchCompleted]
								          , src.[PagelockObject]
								          , src.[DeadlockObject]
								          , src.[KeyLockObject]
								          , src.[KeyLockIndex]
								          , src.[IsVictim]
								          , src.[ProcessID]
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
    FETCH NEXT FROM [timestamps_cursor] INTO @timestamp
END   
CLOSE [timestamps_cursor]   
DEALLOCATE [timestamps_cursor]
----------------------------------

--SELECT * 
--FROM [dbo].[DeadlockStaging] 
--WHERE [timestamp] = '2019-11-14 10:40:22.5566667 +00:00'

SELECT * FROM [dbo].[DeadlockFact]
WHERE COALESCE([DeadlockObject], '0') NOT LIKE '%redgate%'
ORDER BY [DeadlockTime] DESC
--WHERE [DeadlockTime] = '2019-09-05 07:28:49.733'   --'2019-11-14 10:40:22.556'
--WHERE [Procedure] = 'mssqlsystemresource.sys.sp_cci_tuple_mover'
--WHERE DeadlockID IN
--(
--32688143,
--32688167,
--32688168,
--32688191,
--32688214
--)

/*
SELECT   [deadlock_id]
       , [transaction_id]
       , [associated_object_id]
       , [session_id]
FROM     [dbo].[DeadlockStaging]
WHERE	 [timestamp] = '2019-11-14 10:40:22.5566667 +00:00'
AND		 [associated_object_id] = 72057594043301888 --( 72057594040745984 ) --
AND		 [transaction_id] = 35147106466
AND		 [session_id] = 185
ORDER BY [transaction_id]
       , [deadlock_id];
*/
