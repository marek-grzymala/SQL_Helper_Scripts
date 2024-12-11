USE [master]
GO

--DROP EVENT SESSION [ExecPlanAndLocks_Test1] ON SERVER 

CREATE EVENT SESSION [ExecPlanAndLocks_Test1]
ON SERVER
    ADD EVENT [sqlserver].[lock_acquired]
    (SET collect_database_name = (1)
       , collect_resource_description = (1)
     WHERE (
               [sqlserver].[equal_i_sql_unicode_string]([database_name], N'AdventureWorks2019')
        --AND    [package0].[equal_int64]([object_id], (837578022)) ---  SELECT OBJECT_ID('[Production].[BillOfMaterials]')
        AND    [sqlserver].[query_hash_signed] = (-1391535226893487432) 
        /* query_hash_signed obtained by first running this XE session but without this filter clause
           and copying the query_hash_signed value and then RECREATING this XE Session with this filter uncommented
        */
           )
    )
  , ADD EVENT [sqlserver].[query_plan_profile]
    (SET collect_database_name = (1)
     ACTION (
                [sqlos].[scheduler_id]
              , [sqlserver].[database_id]
              , [sqlserver].[is_system]
              , [sqlserver].[plan_handle]
              , [sqlserver].[query_hash_signed]
              , [sqlserver].[query_plan_hash_signed]
              , [sqlserver].[server_instance_name]
              , [sqlserver].[session_id]
              , [sqlserver].[session_nt_username]
              , [sqlserver].[sql_text]
            )
    )
    ADD TARGET [package0].[event_file]
    (SET filename = N'C:\MSSQL\Backup\XEL\ExecPlanAndLocks_Test1.xel', max_file_size = (50), max_rollover_files = (2))
WITH (
         MAX_MEMORY = 4096KB
       , EVENT_RETENTION_MODE = ALLOW_SINGLE_EVENT_LOSS
       , MAX_DISPATCH_LATENCY = 30 SECONDS
       , MAX_EVENT_SIZE = 0KB
       , MEMORY_PARTITION_MODE = NONE
       , TRACK_CAUSALITY = OFF
       , STARTUP_STATE = OFF
     );
GO


