--DECLARE @powerShellVar NVARCHAR(MAX)
IF SERVERPROPERTY ('IsHadrEnabled') = 1
BEGIN
SELECT DISTINCT 
          [Listener Name] = AGL.dns_name
        , [DNS Name] = AGL.dns_name
        , [IP Address] = AGL.ip_configuration_string_from_cluster
        , [TCP Port] = AGL.port
        , [Availability Group] = AGC.name
        , [SQL cluster node name] = RCS.replica_server_name
        , [Replica Role] = ARS.role_desc
        , [Server Name] = RCS.replica_server_name

FROM
 sys.availability_groups_cluster AS AGC
  INNER JOIN sys.dm_hadr_availability_replica_cluster_states AS RCS
   ON
    RCS.group_id = AGC.group_id
  INNER JOIN sys.dm_hadr_availability_replica_states AS ARS
   ON
    ARS.replica_id = RCS.replica_id
  INNER JOIN sys.availability_group_listeners AS AGL
   ON
    AGL.group_id = ARS.group_id
WHERE 1 = 1
--AND ARS.role_desc = 'PRIMARY'

ORDER BY [Listener Name], [Availability Group], [Replica Role]
END
