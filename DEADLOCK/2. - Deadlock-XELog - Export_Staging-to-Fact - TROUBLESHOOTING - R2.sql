SET NOCOUNT ON;

DECLARE @timestamp            DATETIMEOFFSET = '2019-11-14 08:40:22.5550000 +00:00' --'2019-11-26 07:39:28.2233333 +00:00'
	  , @xml_report			  XML
      , @deadlock_id          BIGINT
      , @transaction_id       BIGINT
      , @associated_object_id NVARCHAR(200) --BIGINT
      , @session_id           INT
      , @ErrorMessage         NVARCHAR(4000)
      , @ErrorDeadlockIds     NVARCHAR(4000)
      , @ErrorSeverityDefault INT
      , @ErrorStateDefault    INT
	  , @rn_per_timestamp	  INT
	  , @rn_per_timestamp_max INT
	  , @sql NVARCHAR(MAX)
	  , @matched_with_xml_count INT
SET		@ErrorSeverityDefault = 17;
SET		@ErrorStateDefault	  = 1;

DROP TABLE IF EXISTS [#DeadlockStaging];
CREATE TABLE [#DeadlockStaging] (
	 [event_name]                            NVARCHAR(MAX) NULL
	,[deadlock_timestamp]                    DATETIMEOFFSET NOT NULL
	,[deadlock_timestamp_UTC]                DATETIMEOFFSET NOT NULL
	,[rn_per_timestamp]						 BIGINT NOT NULL
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
	, CONSTRAINT [PK_DeadlockMerge_Timestamp_Rn] PRIMARY KEY CLUSTERED ([deadlock_timestamp], [rn_per_timestamp] ASC)
) ON [PRIMARY];

DROP TABLE IF EXISTS [#DeadlockIds];
CREATE TABLE [#DeadlockIds]
(
    [deadlock_id]            BIGINT         NOT NULL
  , [transaction_id]         BIGINT         NOT NULL
  , [database_id]			 BIGINT			NOT NULL
  , [associated_object_id]   DECIMAL(20, 0) NOT NULL
  , [lockspace_workspace_id] DECIMAL(20, 0) NOT NULL
  , [session_id]             SMALLINT       NOT NULL
  , [rn_per_timestamp]       BIGINT         NOT NULL
  , [matched_with_xml]       BIT            NOT NULL DEFAULT 0
  , CONSTRAINT [PK_DeadlockIds] PRIMARY KEY CLUSTERED (
                                                          [deadlock_id] ASC
                                                        , [transaction_id] ASC
														, [database_id]	ASC
                                                        , [associated_object_id] ASC
														, [lockspace_workspace_id] ASC
                                                        , [session_id] ASC
                                                        , [rn_per_timestamp] ASC
                                                      )
) ON [PRIMARY];


DROP TABLE IF EXISTS [#MergeCandidate];
CREATE TABLE [#MergeCandidate]
(
    [transaction_id]         BIGINT         NOT NULL
  , [associated_object_id]   DECIMAL(20, 0) NOT NULL
  , [session_id]             SMALLINT       NOT NULL
  , CONSTRAINT [PK_MergeCandidate] PRIMARY KEY CLUSTERED (
                                                          [transaction_id] ASC
                                                        , [associated_object_id] ASC
                                                        , [session_id] ASC
                                                      )
) ON [PRIMARY];

TRUNCATE TABLE [#DeadlockStaging];
TRUNCATE TABLE [#DeadlockIds];

--DECLARE [timestamps_cursor] CURSOR FOR        
--      SELECT	  DISTINCT
--				  [deadlock_timestamp]
--      FROM	  [dbo].[DeadlockStaging]
--		ORDER BY  [deadlock_timestamp]
        
--OPEN [timestamps_cursor]   
--FETCH NEXT FROM [timestamps_cursor] INTO @timestamp
--WHILE @@FETCH_STATUS = 0 
--BEGIN
----------------------------------------------------------------------------------------------------------------------------
	IF EXISTS (SELECT [xml_report] FROM [dbo].[DeadlockStaging] WHERE [deadlock_timestamp] = @timestamp AND [xml_report] IS NOT NULL)
	BEGIN
		
		TRUNCATE TABLE [#DeadlockStaging];
		INSERT   INTO  [#DeadlockStaging]
			(
				[event_name]
			  , [deadlock_timestamp]
			  , [deadlock_timestamp_UTC]
			  , [rn_per_timestamp]
			  , [resource_type]
			  , [mode]
			  , [owner_type]
			  , [transaction_id]
			  , [database_id]
			  , [lockspace_workspace_id]
			  , [lockspace_sub_id]
			  , [lockspace_nest_id]
			  , [resource_0]
			  , [resource_1]
			  , [resource_2]
			  , [deadlock_id]
			  , [object_id]
			  , [associated_object_id]
			  , [session_id]
			  , [resource_owner_type]
			  , [resource_description]
			  , [database_name]
			  , [username]
			  , [nt_username]
			  , [duration]
			  , [sql_text]
			  , [xml_report]
			  , [deadlock_cycle_id]
			  , [server_name]
			)
		SELECT [event_name]
			 , [deadlock_timestamp]
			 , [deadlock_timestamp_UTC]
			 , [rn_per_timestamp]
			 , [resource_type]
			 , [mode]
			 , [owner_type]
			 , [transaction_id]
			 , [database_id]
			 , [lockspace_workspace_id]
			 , [lockspace_sub_id]
			 , [lockspace_nest_id]
			 , [resource_0]
			 , [resource_1]
			 , [resource_2]
			 , [deadlock_id]
			 , [object_id]
			 , [associated_object_id]
			 , [session_id]
			 , [resource_owner_type]
			 , [resource_description]
			 , [database_name]
			 , [username]
			 , [nt_username]
			 , [duration]
			 , [sql_text]
			 , [xml_report]
			 , [deadlock_cycle_id]
			 , [server_name]
		FROM [dbo].[DeadlockStaging]
		WHERE [deadlock_timestamp] = @timestamp;

		/*
		SELECT [event_name]
             , [deadlock_timestamp]
             , [deadlock_timestamp_UTC]
             , [rn_per_timestamp]
             , [resource_type]
             , [xml_report]
             , [mode]
             , [owner_type]
             , [transaction_id]
             , [database_id]
             , [lockspace_workspace_id]
             , [lockspace_sub_id]
             , [lockspace_nest_id]
             , [resource_0]
             , [resource_1]
             , [resource_2]
             , [deadlock_id]
             , [object_id]
             , [associated_object_id]
             , [session_id]
             , [resource_owner_type]
             , [resource_description]
             , [database_name]
             , [username]
             , [nt_username]
             , [duration]
             , [sql_text]
             , [deadlock_cycle_id]
             , [server_name] 
		FROM [#DeadlockStaging]
		*/

		TRUNCATE TABLE [#DeadlockIds];
		INSERT INTO [#DeadlockIds]
			(
			 	 [deadlock_id]
			   , [transaction_id]
			   , [database_id]			 
			   , [associated_object_id]
			   , [lockspace_workspace_id]
			   , [session_id]
			   , [rn_per_timestamp]
			)
		SELECT DISTINCT
			     [deadlock_id]
			   , [transaction_id]
			   , [database_id]			 
			   , [associated_object_id]
			   , [lockspace_workspace_id]
			   , [session_id]
			   , [rn_per_timestamp]
		FROM     [#DeadlockStaging]
		WHERE    1 = 1
		AND      [deadlock_id] IS NOT NULL
		AND      [transaction_id] IS NOT NULL
		AND      [associated_object_id] IS NOT NULL
		AND      [lockspace_workspace_id] IS NOT NULL
		AND      [session_id] IS NOT NULL
		ORDER BY [deadlock_id]
			   , [rn_per_timestamp]
			   , [transaction_id]
			   , [associated_object_id]
			   , [session_id];
	
		
		SELECT	 [deadlock_id]
               , [transaction_id] AS [transaction_id (@xactid)]
               , [database_id]
			   , [associated_object_id] AS [associated_object_id (@waitresource)] 
               , [lockspace_workspace_id] 
               , [session_id] AS [session_id (@spid)]
               , [rn_per_timestamp]
               , [matched_with_xml] 
		FROM	 [#DeadlockIds]
		ORDER BY [deadlock_id]
			   , [rn_per_timestamp]
			   , [transaction_id]
			   , [associated_object_id]
			   , [lockspace_workspace_id]
			   , [session_id];	
		
		/* [deadlock_ids_cursor]: ------------------------------------------------------------------------------------------------------------------------------------ */
		
		DECLARE [deadlock_ids_cursor] CURSOR FOR SELECT [deadlock_id] FROM [#DeadlockIds] ORDER BY [deadlock_id]		      
		OPEN [deadlock_ids_cursor]   
		FETCH NEXT FROM [deadlock_ids_cursor] INTO @deadlock_id
		WHILE @@FETCH_STATUS = 0 
		BEGIN

				/* [xmls_cursor]: ------------------------------------------------------------------------------------------------------------------------------------ */

				/* Loop through all [xml_report] values and match them with deadlock_ids: */
				DECLARE [xmls_cursor] CURSOR FOR        
				SELECT  [xml_report]
				FROM    [#DeadlockStaging]
				WHERE	[xml_report] IS NOT NULL;				
				
				OPEN [xmls_cursor]   
				FETCH NEXT FROM [xmls_cursor] INTO @xml_report
				WHILE @@FETCH_STATUS = 0 
				BEGIN
						

						
						SELECT @rn_per_timestamp = MIN(rn_per_timestamp)
							 , @rn_per_timestamp_max = MAX(rn_per_timestamp)
						FROM   [#DeadlockIds]
						WHERE  [matched_with_xml] = 0

						WHILE (@rn_per_timestamp <= @rn_per_timestamp_max)
						BEGIN
							/* below improved version of https://social.technet.microsoft.com/Forums/Windows/en-US/6e29b938-0b62-4a3f-b52e-85e39233b85b/shredding-deadlock-information-from-xml-data?forum=sqldatabaseengine*/			
							
							SELECT @sql = CONCAT(
							'SELECT TOP (1)
									@_transaction_id = Deadlock.Process.value(''/deadlock[1]/process-list[1]/process[', @rn_per_timestamp, ']/@xactid'', ''bigint''),
									@_associated_object_id = Deadlock.Process.value(''/deadlock[1]/process-list[1]/process[', @rn_per_timestamp, ']/@waitresource'', ''nvarchar(max)''),
									@_session_id = Deadlock.Process.value(''/deadlock[1]/process-list[1]/process[', @rn_per_timestamp, ']/@spid'', ''int'')
							FROM    @_xml_report.nodes(''//deadlock/process-list/process'') AS [Deadlock]([Process])');					

							DECLARE @ParmDefinition NVARCHAR(500);
							SET @ParmDefinition = N'@_xml_report xml, @_transaction_id bigint OUTPUT, @_associated_object_id nvarchar(200) OUTPUT, @_session_id int OUTPUT'; 

							EXEC master.sys.sp_executesql @sql, @ParmDefinition
							, @_xml_report = @xml_report
							, @_transaction_id = @transaction_id OUTPUT
							, @_associated_object_id = @associated_object_id OUTPUT
							, @_session_id = @session_id OUTPUT;

							/* ------------------------------------------------------------------------------ */
							; WITH [inputstr]
							AS (SELECT @associated_object_id AS [inputstr])
							, [cte]
							AS (SELECT [value]     AS [first_split] FROM [inputstr] CROSS APPLY STRING_SPLIT(@associated_object_id, ':'))					
							SELECT @matched_with_xml_count = COUNT(*)
							FROM (
									 SELECT ROW_NUMBER() OVER (ORDER BY [cte].[first_split]) AS [Rn]
										  , TRY_PARSE([value] AS BIGINT)					 AS [NumericValue]
									 FROM [cte]
									 CROSS APPLY STRING_SPLIT([cte].[first_split], '(')
									 WHERE ISNUMERIC([value]) = 1
								 ) [p]
							PIVOT (MAX([NumericValue])
							FOR [Rn] IN ([1], [2]))			 AS [pvt]
							INNER JOIN [#DeadlockIds]		 AS [did] 
							ON  [deadlock_id]				 = @deadlock_id
							AND [did].[transaction_id]		 = @transaction_id
							AND [did].[database_id]			 = [pvt].[1]
							AND [did].[associated_object_id] = [pvt].[2]
							AND [did].[session_id]			 = @session_id
							AND [did].[matched_with_xml]	 = 0
							/* ------------------------------------------------------------------------------ */					

							IF (@matched_with_xml_count = 1)
							BEGIN
							/* merge candidate found, do the merge: */

								; WITH [inputstr]
								AS (SELECT @associated_object_id AS [inputstr])
								, [cte]
								AS (SELECT [value]     AS [first_split] FROM [inputstr] CROSS APPLY STRING_SPLIT(@associated_object_id, ':'))					
								SELECT @deadlock_id	   AS [deadlock_id]
									 , @transaction_id AS [transaction_id]
									 , [pvt].[1]	   AS [database_id]
									 , [pvt].[2]	   AS [associated_object_id]
									 , @session_id	   AS [session_id]
									 , @xml_report
								FROM (
										 SELECT ROW_NUMBER() OVER (ORDER BY [cte].[first_split]) AS [Rn]
											  , TRY_PARSE([value] AS BIGINT)					 AS [NumericValue]
										 FROM [cte]
										 CROSS APPLY STRING_SPLIT([cte].[first_split], '(')
										 WHERE ISNUMERIC([value]) = 1
									 ) [p]
								PIVOT (MAX([NumericValue])
								FOR [Rn] IN ([1], [2]))			 AS [pvt]
								INNER JOIN [#DeadlockIds]		 AS [did] 
								ON  [deadlock_id]				 = @deadlock_id
								AND [did].[transaction_id]		 = @transaction_id
								AND [did].[database_id]			 = [pvt].[1]
								AND [did].[associated_object_id] = [pvt].[2]
								AND [did].[session_id]			 = @session_id
								AND [did].[matched_with_xml]	 = 0

								UPDATE [#DeadlockIds] SET [matched_with_xml] = 1 WHERE [rn_per_timestamp] = @rn_per_timestamp AND [deadlock_id] = @deadlock_id;
							END


							SELECT @rn_per_timestamp = MIN(rn_per_timestamp)
							FROM   [#DeadlockIds]
							WHERE  [matched_with_xml] = 0

						END
				FETCH NEXT FROM [xmls_cursor] INTO @xml_report				
				END   
				CLOSE [xmls_cursor]   
				DEALLOCATE [xmls_cursor]
		
				/* end of [xmls_cursor] ---------------------------------------------------------------------------------------------------------------------------- */	
		
		FETCH NEXT FROM [deadlock_ids_cursor] INTO @deadlock_id
		END
		CLOSE [deadlock_ids_cursor]   
		DEALLOCATE [deadlock_ids_cursor]
		
		/* end of [deadlock_ids_cursor] ----------------------------------------------------------------------------------------------------------------------------- */
	
	END
	ELSE
	BEGIN
		SET @ErrorMessage = CONCAT(N'No [xml_report] data found in [dbo].[DeadlockStaging] for the timestamp: ', @timestamp)
		RAISERROR(@ErrorMessage, @ErrorSeverityDefault, @ErrorStateDefault)
	END
/* ------------------------------------------------------------------------------------------------------------------------------------------------------------------- */

--    FETCH NEXT FROM [timestamps_cursor] INTO @timestamp
--END   
--CLOSE [timestamps_cursor]   
--DEALLOCATE [timestamps_cursor]


--AND [transaction_id]		= 35147106466			/* deadlock_id: 32688167 */
--AND [associated_object_id]	= 72057594043301888
--AND [session_id]			= 185

--AND [transaction_id]		= 35147106524			/* deadlock_id: 32688191 */
--AND [associated_object_id]	= 72057594040745984 
--AND [session_id]			= 252
