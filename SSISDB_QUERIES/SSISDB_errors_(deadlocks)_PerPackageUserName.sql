USE SSISDB
GO

DECLARE @DateSince DATE = GETDATE() - 14
DECLARE @UserName NVARCHAR(256) = 'DOMAIN\UserName'
DECLARE @PackageName NVARCHAR(256) = 'PackageName.dtsx'

SELECT 
              O.Operation_Id -- Not much of use 
            , E.Folder_Name AS Project_Name 
            , E.Project_name AS SSIS_Project_Name 
            , EM.Message_Source_Name AS [Component_Name]
            , EM.Package_Name 
            , CONVERT(DATETIME, O.start_time) AS Start_Time 
            , CONVERT(DATETIME, O.end_time) AS End_Time 
            , OM.message as [OperationMessage] 
            , EM.Event_Name
            , OM.message_source_type
            ,E.Environment_Name
            ,E.Executed_as_name AS Executed_By
            
FROM        [SSISDB].[internal].[operations] AS O 
INNER JOIN  [SSISDB].[internal].[event_messages] AS EM 
ON           -- Restrict data by date 
EM.operation_id = O.operation_id 

INNER JOIN  [SSISDB].[internal].[operation_messages] AS OM
ON          EM.operation_id = OM.operation_id 

INNER JOIN  [SSISDB].[internal].[executions] AS E 
ON          OM.Operation_id = E.EXECUTION_ID 

WHERE       O.operation_id IN
(
        SELECT 
                ei.execution_id
        FROM    SSISDB.internal.execution_info ei
        WHERE
                ei.executed_as_name = @UserName AND
                ei.package_name = @PackageName AND
                ei.start_time >= @DateSince AND
                ei.status = 4
)  

AND         OM.message LIKE '%deadlock%'
AND         o.start_time >= @DateSince
