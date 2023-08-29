DECLARE @timestamp            DATETIMEOFFSET = '2019-11-14 10:40:22.5566667 +00:00' --'2019-11-26 07:39:28.2233333 +00:00'
      , @deadlock_id          BIGINT
      , @transaction_id       BIGINT
      , @associated_object_id BIGINT
      , @session_id           INT
      , @ErrorMessage         NVARCHAR(4000)
      , @ErrorDeadlockIds     NVARCHAR(4000)
      , @ErrorSeverityDefault INT
      , @ErrorStateDefault    INT;
SET @ErrorSeverityDefault = 17;
SET @ErrorStateDefault = 1;


DROP TABLE IF EXISTS [#DeadlockMerge];
CREATE TABLE [#DeadlockMerge] (
	 [event_name]                            NVARCHAR(MAX) NULL
	,[timestamp]                             DATETIMEOFFSET NOT NULL
	,[timestamp (UTC)]                       DATETIMEOFFSET NOT NULL
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
	, CONSTRAINT [PK_DeadlockMerge_Timestamp_Rn] PRIMARY KEY CLUSTERED ([timestamp], [rn_per_timestamp] ASC)
) ON [PRIMARY];

DROP TABLE IF EXISTS [#DeadlockIds];
CREATE TABLE [#DeadlockIds]
(
    [deadlock_id]          BIGINT		  NOT NULL
  , [transaction_id]       BIGINT		  NOT NULL
  , [associated_object_id] DECIMAL(20, 0) NOT NULL
  , [session_id]           SMALLINT		  NOT NULL
  , [rn_per_timestamp]	   BIGINT
  , CONSTRAINT [PK_DeadlockIds] PRIMARY KEY CLUSTERED ([deadlock_id] ASC, [transaction_id] ASC, [associated_object_id] ASC, [session_id] ASC, [rn_per_timestamp] ASC)
) ON [PRIMARY];

TRUNCATE TABLE [#DeadlockMerge];

IF EXISTS (SELECT [xml_report] FROM [dbo].[DeadlockStaging] WHERE [timestamp] = @timestamp AND [xml_report] IS NOT NULL)
BEGIN
	INSERT INTO [#DeadlockMerge]
		(
			[event_name]
		  , [timestamp]
		  , [timestamp (UTC)]
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
		 , [timestamp]
		 , [timestamp (UTC)]
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
	WHERE [timestamp] = @timestamp;

	INSERT INTO [#DeadlockIds] ([deadlock_id], [transaction_id], [associated_object_id], [session_id], [rn_per_timestamp])
	SELECT DISTINCT
	         [deadlock_id]
	       , [transaction_id]
	       , [associated_object_id]
	       , [session_id]
		   , [rn_per_timestamp]
	FROM     [#DeadlockMerge]
	WHERE	 1 = 1
	AND		 [deadlock_id]			IS NOT NULL
	AND		 [transaction_id]		IS NOT NULL
	AND		 [associated_object_id] IS NOT NULL
	AND		 [session_id]			IS NOT NULL
	ORDER BY [deadlock_id]
		   , [rn_per_timestamp]
	       , [transaction_id]
	       , [associated_object_id]
	       , [session_id]

	SELECT * FROM [#DeadlockIds]
	ORDER BY [deadlock_id]
		   , [rn_per_timestamp]
		   , [transaction_id]
		   , [associated_object_id]
		   , [session_id];
END
ELSE
BEGIN
	SET @ErrorMessage = CONCAT(N'No [xml_report] data found in [dbo].[DeadlockStaging] for the timestamp: ', @timestamp)
	RAISERROR(@ErrorMessage, @ErrorSeverityDefault, @ErrorStateDefault)
END


--AND [transaction_id]		= 35147106466			/* deadlock_id: 32688167 */
--AND [associated_object_id]	= 72057594043301888
--AND [session_id]			= 185

--AND [transaction_id]		= 35147106524			/* deadlock_id: 32688191 */
--AND [associated_object_id]	= 72057594040745984 
--AND [session_id]			= 252
