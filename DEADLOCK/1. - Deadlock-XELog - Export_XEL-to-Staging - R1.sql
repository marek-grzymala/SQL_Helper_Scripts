USE [DeadlockDemo]
GO

SET NOCOUNT ON;

DECLARE @XeName NVARCHAR(256)
	  , @XeFilePath NVARCHAR(2000)
      , @ErrorMessage NVARCHAR(4000)
      , @ErrorSeverityDefault INT
      , @ErrorStateDefault    INT;
SET		@ErrorSeverityDefault = 20;
SET		@ErrorStateDefault	  = 1;

/* set the variables: */
SET @XeName = N'deadlock_capture';

/* to specify just one xel file replace the file name below (if null the default filename pattern for that session will be used): */
SET @XeFilePath = N'C:\MSSQL\Backup\XEL\sAnalyseAudit\system_health_0_*.xel';

IF (@XeFilePath IS NULL)
BEGIN
	SELECT @XeFilePath = STUFF(CONVERT(NVARCHAR(2000), [esf].[value])
							, LEN(CONVERT(NVARCHAR(2000), [esf].[value]))
							- (CHARINDEX('.', REVERSE(CONVERT(NVARCHAR(2000), [esf].[value]))) - 1), 0, '*')
	FROM	[sys].[server_event_sessions] AS [ses]
	JOIN	[sys].[server_event_session_fields] AS [esf] ON [ses].[event_session_id] = [esf].[event_session_id]
	WHERE	[ses].[name] = @XeName
	AND		[esf].[name] = 'filename';
END
IF (@XeFilePath IS NULL)
BEGIN
		SET @ErrorMessage = CONCAT(N'@XeFilePath is null and no Extended Event Session: [', @XeName, '] found in [server_event_sessions]')
		RAISERROR(@ErrorMessage, @ErrorSeverityDefault, @ErrorStateDefault) WITH LOG;
END

DROP TABLE IF EXISTS [dbo].[DeadlockStaging];
CREATE TABLE [dbo].[DeadlockStaging]
(
    [event_name]             NVARCHAR(1024)    NOT NULL
  , [deadlock_timestamp]     DATETIMEOFFSET    NOT NULL
  , [deadlock_timestamp_UTC] DATETIMEOFFSET    NOT NULL
  , [rn_per_timestamp]       BIGINT            NOT NULL
  , [resource_type]          NVARCHAR(1024)    NULL
  , [mode]                   NVARCHAR(1024)    NULL
  , [owner_type]             NVARCHAR(1024)    NULL
  , [transaction_id]         BIGINT            NULL
  , [database_id]            BIGINT            NULL
  , [lockspace_workspace_id] DECIMAL(20, 0)    NULL
  , [lockspace_sub_id]       BIGINT            NULL
  , [lockspace_nest_id]      BIGINT            NULL
  , [resource_0]             BIGINT            NULL
  , [resource_1]             BIGINT            NULL
  , [resource_2]             BIGINT            NULL
  , [deadlock_id]            BIGINT            NULL
  , [object_id]              INT               NULL
  , [associated_object_id]   DECIMAL(20, 0)    NULL
  , [session_id]             SMALLINT          NULL
  , [resource_owner_type]    NVARCHAR(1024)    NULL
  , [resource_description]   NVARCHAR(1024)    NULL
  , [database_name]          NVARCHAR(1024)    NULL
  , [username]               NVARCHAR(1024)    NULL
  , [nt_username]            NVARCHAR(1024)    NULL
  , [xml_report]             XML               NULL
  , [deadlock_cycle_id]      DECIMAL(20, 0)    NULL
  , [server_name]            NVARCHAR(1024)    NULL
  , [duration]               DECIMAL(20, 0)    NULL
  , [sql_text]               NVARCHAR(1024)    NULL 
  , CONSTRAINT [PK_DeadlockStaging_Timestamp_Rn] PRIMARY KEY CLUSTERED ([deadlock_timestamp], [rn_per_timestamp] ASC)
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY];


DECLARE 
  @XmlData XML
, @name	                        NVARCHAR(1024) 

-----------------------------------------
, @event_name VARCHAR(128)
, @timestamp	                DATETIMEOFFSET
, @timestamp_UTC	            DATETIMEOFFSET
, @rn_per_timestamp				BIGINT
, @resource_type	            NVARCHAR(1024) 
, @mode	                        NVARCHAR(1024) 
, @owner_type	                NVARCHAR(1024) 
, @transaction_id	            BIGINT	 
, @database_id	                BIGINT	 
, @lockspace_workspace_id	    VARCHAR(1024)
, @lockspace_sub_id	            BIGINT	 
, @lockspace_nest_id	        BIGINT	 
, @resource_0	                BIGINT	 
, @resource_1	                BIGINT	 
, @resource_2	                BIGINT	 
, @xml_report_id	            BIGINT	 
, @object_id	                INT	 
, @associated_object_id	        DECIMAL(20)
, @session_id	                INT	 
, @resource_owner_type	        NVARCHAR(1024) 
, @resource_description	        NVARCHAR(1024) 
, @database_name	            NVARCHAR(1024) 
, @username	                    NVARCHAR(1024) 
, @nt_username	                NVARCHAR(1024) 
, @xml_report	                XML 
, @xml_report_cycle_id	        DECIMAL(20)
, @server_name	                NVARCHAR(1024) 
, @duration	                    DECIMAL(20)
, @sql_text	                    NVARCHAR(1024)
-----------------------------------------

TRUNCATE TABLE [dbo].[DeadlockStaging]

DROP TABLE IF EXISTS [#RawData]
CREATE TABLE [#RawData]
(
    [Rn]         INTEGER    IDENTITY(1, 1) NOT NULL
  , [XmlData]    XML
  , [EventName]  VARCHAR(52)
  , [Processed]  BIT        DEFAULT 0
  , CONSTRAINT [PK_DeadlockStaging_Rn] PRIMARY KEY CLUSTERED ([Rn] ASC)
);
INSERT INTO [#RawData] ([XmlData], [EventName])
SELECT
            CAST(event_data AS XML) AS [XmlData],
            CASE
                WHEN object_name = 'lock_deadlock_chain'            THEN 'lock_deadlock_chain'
                WHEN object_name = 'xml_deadlock_report'            THEN 'xml_deadlock_report'
                WHEN object_name = 'database_xml_deadlock_report'   THEN 'database_xml_deadlock_report'
                WHEN object_name = 'lock_deadlock'                  THEN 'lock_deadlock'
                ELSE 'unknown entry type or not a deadlock XE session data'
            END AS [EventName]
FROM      sys.fn_xe_file_target_read_file(@XeFilePath, 'Not used in 2012+', NULL, NULL)
WHERE	  object_name IN ('lock_deadlock_chain', 'xml_deadlock_report', 'database_xml_deadlock_report', 'lock_deadlock')

DECLARE @CurrentRn INT = (SELECT MIN(Rn) FROM [#RawData] WHERE [Processed] = 0)
DECLARE @MaxRn INT = (SELECT MAX(Rn) FROM [#RawData])
DECLARE @PercentCompleted INT = 0;
SET @rn_per_timestamp = 1;

WHILE (@CurrentRn <= @MaxRn) 
BEGIN
	IF (@CurrentRn * 100)/@MaxRn <> @PercentCompleted
	BEGIN
		SET @PercentCompleted = (@CurrentRn * 100)/@MaxRn;
		PRINT(CONCAT('Percent completed: ', @PercentCompleted))
	END
	SELECT	@XmlData = [XmlData]
		  , @event_name = [EventName]
	FROM	[#RawData]
	WHERE	[Rn] = @CurrentRn;
	--============================================================================
	IF @event_name IN ('database_xml_deadlock_report', 'xml_deadlock_report')
	BEGIN
	    SELECT  @database_name = k.value('data(.)','VARCHAR(1024)') 
	    FROM    @XmlData.nodes('/event/data') p(k) 
	    WHERE   (k.value('@name','VARCHAR(1024)')) = 'database_name'
	
	    SELECT  @server_name = k.value('data(.)','VARCHAR(1024)') 
	    FROM    @XmlData.nodes('/event/data') p(k) 
	    WHERE   (k.value('@name','VARCHAR(1024)')) = 'server_name'
	    
	    SELECT  @xml_report = T.c.query('.') 
	    FROM    @XmlData.nodes('/event/data/value/deadlock') T(c)
	END
	--============================================================================
	
	--------------------------------------------------------------------------
	-- Populate Deadlock-XE-Staging table:
	--------------------------------------------------------------------------
	--SELECT @timestamp = DATEADD(mi, DATEPART(TZ, SYSDATETIMEOFFSET()), ([event].[data].[value]('@timestamp', 'varchar(128)'))) FROM @XmlData.nodes('/event') AS [event]([data]);
	SELECT @timestamp = [event].[data].[value]('@timestamp', 'varchar(128)') FROM @XmlData.nodes('/event') AS [event]([data]);
	IF EXISTS (SELECT [deadlock_timestamp] FROM [dbo].[DeadlockStaging] WHERE [deadlock_timestamp] = @timestamp)
	BEGIN
		SELECT @rn_per_timestamp = MAX([rn_per_timestamp]) + 1 FROM [dbo].[DeadlockStaging]	WHERE [deadlock_timestamp] = @timestamp
	END
	ELSE 
	BEGIN
		SELECT @rn_per_timestamp = 1
	END
	
	SELECT @timestamp_UTC		   = [event].[data].[value]('@timestamp', 'varchar(128)') FROM @XmlData.nodes('/event') AS [event]([data]);
	SELECT @resource_type          = k.value('text[1]','VARCHAR(1024)')  FROM @XmlData.nodes('/event/data')   p(k) WHERE (k.value('@name','VARCHAR(1024)')) = 'resource_type'
	SELECT @mode                   = k.value('text[1]','VARCHAR(1024)')  FROM @XmlData.nodes('/event/data')   p(k) WHERE (k.value('@name','VARCHAR(1024)')) = 'mode'
	SELECT @owner_type             = k.value('text[1]','VARCHAR(1024)')  FROM @XmlData.nodes('/event/data')   p(k) WHERE (k.value('@name','VARCHAR(1024)')) = 'owner_type'
	SELECT @transaction_id         = k.value('data(.)','VARCHAR(1024)')  FROM @XmlData.nodes('/event/data')   p(k) WHERE (k.value('@name','VARCHAR(1024)')) = 'transaction_id'
	SELECT @database_id            = k.value('data(.)','VARCHAR(1024)')  FROM @XmlData.nodes('/event/data')   p(k) WHERE (k.value('@name','VARCHAR(1024)')) = 'database_id'
	SELECT @lockspace_workspace_id = k.value('data(.)','VARCHAR(1024)')  FROM @XmlData.nodes('/event/data')   p(k) WHERE (k.value('@name','VARCHAR(1024)')) = 'lockspace_workspace_id'
	SELECT @lockspace_sub_id       = k.value('data(.)','VARCHAR(1024)')  FROM @XmlData.nodes('/event/data')   p(k) WHERE (k.value('@name','VARCHAR(1024)')) = 'lockspace_sub_id'
	SELECT @lockspace_nest_id      = k.value('data(.)','VARCHAR(1024)')  FROM @XmlData.nodes('/event/data')   p(k) WHERE (k.value('@name','VARCHAR(1024)')) = 'lockspace_nest_id'
	SELECT @resource_0             = k.value('data(.)','VARCHAR(1024)')  FROM @XmlData.nodes('/event/data')   p(k) WHERE (k.value('@name','VARCHAR(1024)')) = 'resource_0'
	SELECT @resource_1             = k.value('data(.)','VARCHAR(1024)')  FROM @XmlData.nodes('/event/data')   p(k) WHERE (k.value('@name','VARCHAR(1024)')) = 'resource_1'
	SELECT @resource_2             = k.value('data(.)','VARCHAR(1024)')  FROM @XmlData.nodes('/event/data')   p(k) WHERE (k.value('@name','VARCHAR(1024)')) = 'resource_2'
	SELECT @xml_report_id          = k.value('data(.)','VARCHAR(1024)')  FROM @XmlData.nodes('/event/data')   p(k) WHERE (k.value('@name','VARCHAR(1024)')) = 'deadlock_id'
	SELECT @object_id              = k.value('data(.)','VARCHAR(1024)')  FROM @XmlData.nodes('/event/data')   p(k) WHERE (k.value('@name','VARCHAR(1024)')) = 'object_id'
	SELECT @associated_object_id   = k.value('data(.)','VARCHAR(1024)')  FROM @XmlData.nodes('/event/data')   p(k) WHERE (k.value('@name','VARCHAR(1024)')) = 'associated_object_id'
	SELECT @session_id             = k.value('data(.)','VARCHAR(1024)')  FROM @XmlData.nodes('/event/data')   p(k) WHERE (k.value('@name','VARCHAR(1024)')) = 'session_id'
	SELECT @resource_owner_type    = k.value('text[1]','VARCHAR(1024)')  FROM @XmlData.nodes('/event/data')   p(k) WHERE (k.value('@name','VARCHAR(1024)')) = 'resource_owner_type'
	SELECT @resource_description   = k.value('data(.)','VARCHAR(1024)')  FROM @XmlData.nodes('/event/data')   p(k) WHERE (k.value('@name','VARCHAR(1024)')) = 'resource_description'	
	SELECT @username               = k.value('data(.)','VARCHAR(1024)')  FROM @XmlData.nodes('/event/action') p(k) WHERE (k.value('@name','VARCHAR(1024)')) = 'username'
	SELECT @nt_username            = k.value('data(.)','VARCHAR(1024)')  FROM @XmlData.nodes('/event/action') p(k) WHERE (k.value('@name','VARCHAR(1024)')) = 'nt_username'
	SELECT @xml_report_cycle_id    = k.value('data(.)','VARCHAR(1024)')  FROM @XmlData.nodes('/event/data')   p(k) WHERE (k.value('@name','VARCHAR(1024)')) = 'deadlock_cycle_id'
	SELECT @duration               = k.value('data(.)','VARCHAR(1024)')  FROM @XmlData.nodes('/event/data')   p(k) WHERE (k.value('@name','VARCHAR(1024)')) = 'duration'
	SELECT @sql_text               = k.value('data(.)', 'VARCHAR(1000)') FROM @XmlData.nodes('/event/action') p(k) WHERE (k.value('@name','VARCHAR(1024)')) = 'sql_text'
	----------------------------------------------------------------------------------
	
	    	INSERT [dbo].[DeadlockStaging] (
	                     [event_name]                     
		                ,[deadlock_timestamp]
		                ,[deadlock_timestamp_UTC]
						,[rn_per_timestamp]
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
		                ,[xml_report]               
		                ,[deadlock_cycle_id]        
		                ,[server_name]              
		                ,[duration]                 
		                ,[sql_text]                 
	        )
	            SELECT 
	                      [event_name]                = @event_name
	                    , [deadlock_timestamp]		  = @timestamp
						, [deadlock_timestamp_UTC]    = @timestamp_UTC
						, [rn_per_timestamp]		  = @rn_per_timestamp
	                    , [resource_type]             = @resource_type
	                    , [mode]                      = @mode
	                    , [owner_type]                = @owner_type
	                    , [transaction_id]            = @transaction_id
	                    , [database_id]               = @database_id
	                    , [lockspace_workspace_id]    = CONVERT(BIGINT, CONVERT(VARBINARY, @lockspace_workspace_id, 1))
	                    , [lockspace_sub_id]          = @lockspace_sub_id
	                    , [lockspace_nest_id]         = @lockspace_nest_id
	                    , [resource_0]                = @resource_0
	                    , [resource_1]                = @resource_1
	                    , [resource_2]                = @resource_2
	                    , [deadlock_id]               = @xml_report_id
	                    , [object_id]                 = @object_id
	                    , [associated_object_id]      = @associated_object_id
	                    , [session_id]                = @session_id   
	                    , [resource_owner_type]       = @resource_owner_type
	                    , [resource_description]      = @resource_description
	                    , [database_name]             = @database_name
	                    , [username]                  = @username
	                    , [nt_username]               = @nt_username
	                    , [xml_report]                = CONVERT(XML, @xml_report)
	                    , [deadlock_cycle_id]         = @xml_report_cycle_id
	                    , [server_name]               = @server_name
	                    , [duration]                  = CONVERT(DECIMAL(20, 0), @duration)
	                    , [sql_text]                  = @sql_text

            SELECT @resource_type           = NULL
            SELECT @mode                    = NULL
            SELECT @owner_type              = NULL
            SELECT @transaction_id          = NULL
            SELECT @database_id             = NULL
            SELECT @lockspace_workspace_id  = NULL
            SELECT @lockspace_sub_id        = NULL
            SELECT @lockspace_nest_id       = NULL
            SELECT @resource_0              = NULL
            SELECT @resource_1              = NULL
            SELECT @resource_2              = NULL
            SELECT @xml_report_id           = NULL
            SELECT @object_id               = NULL
            SELECT @associated_object_id    = NULL
            SELECT @session_id              = NULL
            SELECT @resource_owner_type     = NULL
            SELECT @resource_description    = NULL
            SELECT @database_name           = NULL
            SELECT @username                = NULL
            SELECT @nt_username             = NULL
            SELECT @xml_report              = NULL
            SELECT @xml_report_cycle_id     = NULL
            SELECT @server_name             = NULL
            SELECT @duration                = NULL
            SELECT @sql_text                = NULL

	UPDATE [#RawData] SET [Processed] = 1 WHERE [Rn] = @CurrentRn
	SELECT @CurrentRn = MIN(Rn) FROM [#RawData] WHERE [Processed] = 0
END

DROP TABLE IF EXISTS [#RawData];
GO

SELECT [event_name]
	 , [deadlock_timestamp]
     , [resource_type]
     , [deadlock_id]
     , [transaction_id]
     , [associated_object_id]
     , [lockspace_workspace_id]
     , [mode]
     , [owner_type]
     , [database_id]
     , [lockspace_sub_id]
     , [lockspace_nest_id]
     , [resource_0]
     , [resource_1]
     , [resource_2]
     , [object_id]
     , [session_id]
     , [resource_owner_type]
     , [resource_description]
     , [database_name]
     , [username]
     , [nt_username]
     , [xml_report]
     , [deadlock_cycle_id]
     , [server_name]
     , [duration]
     , [sql_text]
--SELECT DISTINCT [lockspace_workspace_id]
FROM [dbo].[DeadlockStaging] AS [ds]
--WHERE [deadlock_timestamp] = '2019-11-14 08:40:22.5550000 +00:00'
ORDER BY ds.[deadlock_timestamp] DESC
       , [transaction_id]
       , [deadlock_id]
       , [database_name]
       , [deadlock_cycle_id]
       , [event_name]
GO

/*
SELECT
	[ds].[deadlock_timestamp]
  , [ds].[resource_type]
  , [ds].[resource_owner_type]
  , MAX([ds].[rn_per_timestamp]) AS [max_rn_per_timestamp]
FROM [dbo].[DeadlockStaging] AS [ds]
GROUP BY [ds].[deadlock_timestamp], [ds].[resource_type], [ds].[resource_owner_type]
ORDER BY [max_rn_per_timestamp] DESC 
*/