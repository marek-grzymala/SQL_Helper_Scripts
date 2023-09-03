--- YOU MUST EXECUTE THE FOLLOWING SCRIPT IN SQLCMD MODE.!!!!!
USE [master]
GO

DECLARE @SqlListenerName NVARCHAR(255) = N'SqlListenerName'
DECLARE @SqlListenerIp VARCHAR(15) = '10.0.0.8'
DECLARE @SqlListenerSubnetMask VARCHAR(15) = N'255.255.255.0'
DECLARE @SqlListenerTcpPort INT = 61433

:Connect PrimaryNodeName,51433

CREATE ENDPOINT [Hadr_endpoint] 
	AS TCP (LISTENER_PORT = 61433)
	FOR DATA_MIRRORING (ROLE = ALL, ENCRYPTION = REQUIRED ALGORITHM AES)


IF (SELECT 1 FROM sys.endpoints WHERE name = N'Hadr_endpoint') <> 0
BEGIN
	ALTER ENDPOINT [Hadr_endpoint] STATE = STARTED
END

GRANT CONNECT ON ENDPOINT::[Hadr_endpoint] TO [NT Service\MSSQL$INST1]

:Connect SecondaryNodeName,51433

CREATE ENDPOINT [Hadr_endpoint] 
	AS TCP (LISTENER_PORT = 61433)
	FOR DATA_MIRRORING (ROLE = ALL, ENCRYPTION = REQUIRED ALGORITHM AES)

IF (SELECT 1 FROM sys.endpoints WHERE name = N'Hadr_endpoint') <> 0
BEGIN
	ALTER ENDPOINT [Hadr_endpoint] STATE = STARTED
END

GRANT CONNECT ON ENDPOINT::[Hadr_endpoint] TO [NT Service\MSSQL$INST2]

:Connect PrimaryNodeName,51433

IF EXISTS(SELECT * FROM sys.server_event_sessions WHERE name='AlwaysOn_health')
BEGIN
  ALTER EVENT SESSION [AlwaysOn_health] ON SERVER WITH (STARTUP_STATE = ON);
END
IF NOT EXISTS(SELECT * FROM sys.dm_xe_sessions WHERE name='AlwaysOn_health')
BEGIN
  ALTER EVENT SESSION [AlwaysOn_health] ON SERVER STATE=START;
END

:Connect SecondaryNodeName,51433

IF EXISTS(SELECT * FROM sys.server_event_sessions WHERE name='AlwaysOn_health')
BEGIN
  ALTER EVENT SESSION [AlwaysOn_health] ON SERVER WITH (STARTUP_STATE = ON);
END
IF NOT EXISTS(SELECT * FROM sys.dm_xe_sessions WHERE name='AlwaysOn_health')
BEGIN
  ALTER EVENT SESSION [AlwaysOn_health] ON SERVER STATE=START;
END

:Connect PrimaryNodeName,51433


CREATE AVAILABILITY GROUP [Test-AG]
WITH (AUTOMATED_BACKUP_PREFERENCE = SECONDARY)
FOR DATABASE [AdventureWorks2014]
REPLICA ON N'PrimaryNodeName\SQL_INSTANCE_NAME' WITH (ENDPOINT_URL = N'TCP://PrimaryNodeName.YourDomainName:61433', FAILOVER_MODE = MANUAL, AVAILABILITY_MODE = SYNCHRONOUS_COMMIT, BACKUP_PRIORITY = 50, SECONDARY_ROLE(ALLOW_CONNECTIONS = NO)),
	N'SecondaryNodeName\SQL_INSTANCE_NAME' WITH (ENDPOINT_URL = N'TCP://SecondaryNodeName.YourDomainName:61433', FAILOVER_MODE = AUTOMATIC, AVAILABILITY_MODE = SYNCHRONOUS_COMMIT, BACKUP_PRIORITY = 50, SECONDARY_ROLE(ALLOW_CONNECTIONS = NO));


:Connect PrimaryNodeName,51433


ALTER AVAILABILITY GROUP [Test-AG]
ADD LISTENER @SqlListenerName (
WITH IP
((@SqlListenerIp, @SqlListenerSubnetMask)
)
, PORT = @SqlListenerTcpPort);

GO

:Connect SecondaryNodeName,51433

ALTER AVAILABILITY GROUP [Test-AG] JOIN;

GO

:Connect SecondaryNodeName,51433


-- Wait for the replica to start communicating
BEGIN TRY
    DECLARE @conn BIT
    DECLARE @count INT
    DECLARE @replica_id UNIQUEIDENTIFIER
    DECLARE @group_id UNIQUEIDENTIFIER
    SET @conn = 0
    SET @count = 30 -- wait for 5 minutes 

    IF  (SERVERPROPERTY('IsHadrEnabled') = 1)
    AND (ISNULL((
                    SELECT [member_state]
                    FROM [master].[sys].[dm_hadr_cluster_members]
                    WHERE UPPER([member_name] COLLATE Latin1_General_CI_AS) = UPPER(CAST(SERVERPROPERTY('ComputerNamePhysicalNetBIOS') AS NVARCHAR(256)) COLLATE Latin1_General_CI_AS)
                )
              , 0
               ) <> 0
        )
    AND (ISNULL((SELECT [state] FROM [master].[sys].[database_mirroring_endpoints]), 1) = 0)
    BEGIN
        SELECT @group_id = [group_id] FROM [master].[sys].[availability_groups] AS [ags] WHERE [name] = N'Test-AG'
        SELECT @replica_id = [replica_id]
        FROM [master].[sys].[availability_replicas] AS [replicas]
        WHERE UPPER([replica_server_name] COLLATE Latin1_General_CI_AS) = UPPER(@@SERVERNAME COLLATE Latin1_General_CI_AS)
        AND   [group_id] = @group_id
        WHILE @conn <> 1 AND @count > 0
        BEGIN
            SET @conn = ISNULL((
                                   SELECT [connected_state]
                                   FROM [master].[sys].[dm_hadr_availability_replica_states] AS [states]
                                   WHERE [replica_id] = @replica_id
                               )
                             , 1
                              )
            IF @conn = 1
            BEGIN
                -- exit loop when the replica is connected, or if the query cannot find the replica status
                BREAK
            END
            WAITFOR DELAY '00:00:10'
            SET @count = @count - 1
        END
    END
END TRY
BEGIN CATCH
-- If the wait loop fails, do not stop execution of the alter database statement
END CATCH
ALTER DATABASE [AdventureWorks2014] SET HADR AVAILABILITY GROUP = [Test-AG];

GO


GO


