USE DeadlockDumps
GO


DECLARE 
        @XtendedEventFilePath NVARCHAR(256) = '/tmp/Deadlock detection*.xel'
        , @XmlData XML
        , @ObjectName VARCHAR(128)

-----------------------------------------
, @name	                        NVARCHAR(1024) 
, @timestamp	                DATETIMEOFFSET(7)
, @timestamp_UTC	            DATETIMEOFFSET(7)
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
, @deadlock_id	                BIGINT	 
, @object_id	                INT	 
, @associated_object_id	        DECIMAL(20)
, @session_id	                INT	 
, @resource_owner_type	        NVARCHAR(1024) 
, @resource_description	        NVARCHAR(1024) 
, @database_name	            NVARCHAR(1024) 
, @username	                    NVARCHAR(1024) 
, @nt_username	                NVARCHAR(1024) 
, @xml_report	                NVARCHAR(MAX) 
, @deadlock_cycle_id	        DECIMAL(20)
, @server_name	                NVARCHAR(1024) 
, @duration	                    DECIMAL(20)
, @sql_text	                    NVARCHAR(1024)
-----------------------------------------
DROP TABLE IF EXISTS [#DeadlockDetails]
CREATE TABLE [#DeadlockDetails] (
	[name]                      NVARCHAR(1024) NULL,
	[timestamp]                 DATETIMEOFFSET(7) NULL,
	[timestamp (UTC)]           DATETIMEOFFSET(7) NULL,
	[resource_type]             NVARCHAR(1024) NULL,
	[mode]                      NVARCHAR(1024) NULL,
	[owner_type]                NVARCHAR(1024) NULL,
	[transaction_id]            BIGINT NULL,
	[database_id]               BIGINT NULL,
	[lockspace_workspace_id]    DECIMAL(20, 0) NULL,
	[lockspace_sub_id]          BIGINT NULL,
	[lockspace_nest_id]         BIGINT NULL,
	[resource_0]                BIGINT NULL,
	[resource_1]                BIGINT NULL,
	[resource_2]                BIGINT NULL,
	[deadlock_id]               BIGINT NULL,
	[object_id]                 INT NULL,
	[associated_object_id]      DECIMAL(20, 0) NULL,
	[session_id]                SMALLINT NULL,
	[resource_owner_type]       NVARCHAR(1024) NULL,
	[resource_description]      NVARCHAR(1024) NULL,
	[database_name]             NVARCHAR(1024) NULL,
	[username]                  NVARCHAR(1024) NULL,
	[nt_username]               NVARCHAR(1024) NULL,
	[xml_report]                NVARCHAR(MAX) NULL,
	[deadlock_cycle_id]         DECIMAL(20, 0) NULL,
	[server_name]               NVARCHAR(1024) NULL,
	[duration]                  DECIMAL(20, 0) NULL,
	[sql_text]                  NVARCHAR(1024) NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

DECLARE my_cursor CURSOR FOR 

    SELECT
               CAST(event_data AS XML) AS XmlData,
               CASE
                    WHEN object_name = 'lock_deadlock_chain'            THEN 'lock_deadlock_chain'
                    WHEN object_name = 'xml_deadlock_report'            THEN 'xml_deadlock_report'
                    WHEN object_name = 'database_xml_deadlock_report'   THEN 'database_xml_deadlock_report'
                    WHEN object_name = 'lock_deadlock'                  THEN 'lock_deadlock'
                    ELSE 'unknown entry type or not a deadlock XE session data'
               END AS [object_name]
    FROM      sys.fn_xe_file_target_read_file(@XtendedEventFilePath, 'Not used in 2012', NULL, NULL)
    
	
OPEN my_cursor   
FETCH NEXT FROM my_cursor INTO @XmlData, @ObjectName 
WHILE @@FETCH_STATUS = 0   
BEGIN
--------------------------------------------------------------------------
SELECT
    [row_number] = ROW_NUMBER() OVER(ORDER BY k.value('@name','VARCHAR(50)')),
    [name] = k.value('@name','VARCHAR(50)'),
    [value] = k.value('data(.)','VARCHAR(50)'),
    [text_full] = k.value('.','VARCHAR(50)'),
    [value] = k.value('value[1]','VARCHAR(50)'),
    [text] = k.value('text[1]','VARCHAR(50)')
    --b.value('.', 'varchar(100)')

    --b.value('(.)','VARCHAR(50)') AS ColumnName,  -- get attribute name
    --b.value('(.)','VARCHAR(MAX)') AS Value  -- get attribute value
FROM 

        @XmlData.nodes('/event/data') p(k)
        CROSS APPLY k.nodes('/.') a(b)

--WHERE k.value('text[1]','VARCHAR(50)') IS NOT NULL
ORDER BY 
    [name]
--------------------------------------------------------------------------
-- Populate Deadlock-XE-Dump table:
--------------------------------------------------------------------------
SELECT @resource_type           = k.value('text[1]','VARCHAR(1024)') FROM @XmlData.nodes('/event/data') p(k) WHERE (k.value('@name','VARCHAR(1024)')) = 'resource_type'
SELECT @mode                    = k.value('text[1]','VARCHAR(1024)') FROM @XmlData.nodes('/event/data') p(k) WHERE (k.value('@name','VARCHAR(1024)')) = 'mode'
SELECT @owner_type              = k.value('text[1]','VARCHAR(1024)') FROM @XmlData.nodes('/event/data') p(k) WHERE (k.value('@name','VARCHAR(1024)')) = 'owner_type'
SELECT @transaction_id          = k.value('data(.)','VARCHAR(1024)') FROM @XmlData.nodes('/event/data') p(k) WHERE (k.value('@name','VARCHAR(1024)')) = 'transaction_id'
SELECT @database_id             = k.value('data(.)','VARCHAR(1024)') FROM @XmlData.nodes('/event/data') p(k) WHERE (k.value('@name','VARCHAR(1024)')) = 'database_id'
SELECT @lockspace_workspace_id  = k.value('data(.)','VARCHAR(1024)') FROM @XmlData.nodes('/event/data') p(k) WHERE (k.value('@name','VARCHAR(1024)')) = 'lockspace_workspace_id'
SELECT @lockspace_sub_id        = k.value('data(.)','VARCHAR(1024)') FROM @XmlData.nodes('/event/data') p(k) WHERE (k.value('@name','VARCHAR(1024)')) = 'lockspace_sub_id'
SELECT @lockspace_nest_id       = k.value('data(.)','VARCHAR(1024)') FROM @XmlData.nodes('/event/data') p(k) WHERE (k.value('@name','VARCHAR(1024)')) = 'lockspace_nest_id'
SELECT @resource_0              = k.value('data(.)','VARCHAR(1024)') FROM @XmlData.nodes('/event/data') p(k) WHERE (k.value('@name','VARCHAR(1024)')) = 'resource_0'
SELECT @resource_1              = k.value('data(.)','VARCHAR(1024)') FROM @XmlData.nodes('/event/data') p(k) WHERE (k.value('@name','VARCHAR(1024)')) = 'resource_1'
SELECT @resource_2              = k.value('data(.)','VARCHAR(1024)') FROM @XmlData.nodes('/event/data') p(k) WHERE (k.value('@name','VARCHAR(1024)')) = 'resource_2'
SELECT @deadlock_id             = k.value('data(.)','VARCHAR(1024)') FROM @XmlData.nodes('/event/data') p(k) WHERE (k.value('@name','VARCHAR(1024)')) = 'deadlock_id'
SELECT @object_id               = k.value('data(.)','VARCHAR(1024)') FROM @XmlData.nodes('/event/data') p(k) WHERE (k.value('@name','VARCHAR(1024)')) = 'object_id'
SELECT @associated_object_id    = k.value('data(.)','VARCHAR(1024)') FROM @XmlData.nodes('/event/data') p(k) WHERE (k.value('@name','VARCHAR(1024)')) = 'associated_object_id'
SELECT @session_id              = k.value('data(.)','VARCHAR(1024)') FROM @XmlData.nodes('/event/data') p(k) WHERE (k.value('@name','VARCHAR(1024)')) = 'session_id'
SELECT @resource_owner_type     = k.value('text[1]','VARCHAR(1024)') FROM @XmlData.nodes('/event/data') p(k) WHERE (k.value('@name','VARCHAR(1024)')) = 'resource_owner_type'
SELECT @resource_description    = k.value('data(.)','VARCHAR(1024)') FROM @XmlData.nodes('/event/data') p(k) WHERE (k.value('@name','VARCHAR(1024)')) = 'resource_description'

    ----------------------------------------------------------------------------------
    	INSERT [#DeadlockDetails] (

                     [name]                     
	                ,[timestamp]                
	                ,[timestamp (UTC)]          
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
	                --,[database_name]            
	                --,[username]                 
	                --,[nt_username]              
	                --,[xml_report]               
	                --,[deadlock_cycle_id]        
	                --,[server_name]              
	                --,[duration]                 
	                --,[sql_text]                 
        )
            SELECT 
                        [name]                      = @ObjectName
                    ,   [timestamp]                 = DATEADD(mi, DATEPART(TZ, SYSDATETIMEOFFSET()), (event.data.value('@timestamp', 'varchar(128)')))
                    ,   [timestamp (UTC)]           = event.data.value('@timestamp', 'varchar(128)')
                    ,   [resource_type]             = @resource_type
                    ,   [mode]                      = @mode
                    ,   [owner_type]                = @owner_type
                    ,   [transaction_id]            = @transaction_id
                    ,   [database_id]               = @database_id
                    ,   [lockspace_workspace_id]    = CONVERT(BIGINT, CONVERT(VARBINARY, @lockspace_workspace_id, 1))
                    ,   [lockspace_sub_id]          = @lockspace_sub_id
                    ,   [lockspace_nest_id]         = @lockspace_nest_id
                    ,   [resource_0]                = @resource_0
                    ,   [resource_1]                = @resource_1
                    ,   [resource_2]                = @resource_2
                    ,   [deadlock_id]               = @deadlock_id
                    ,   [object_id]                 = @object_id
                    ,   [associated_object_id]      = @associated_object_id
                    ,   [session_id]                = @session_id   
                    ,   [resource_owner_type]       = @resource_owner_type
                    ,   [resource_description]      = @resource_description

            FROM    @XmlData.nodes('/event') as event(data)

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
            SELECT @deadlock_id             = NULL
            SELECT @object_id               = NULL
            SELECT @associated_object_id    = NULL
            SELECT @session_id              = NULL
            SELECT @resource_owner_type     = NULL
            SELECT @resource_description    = NULL

--------------------------------------------------------------------------	
	FETCH NEXT FROM my_cursor INTO @XmlData, @ObjectName   
END   

CLOSE my_cursor   
DEALLOCATE my_cursor


SELECT * FROM [#DeadlockDetails]