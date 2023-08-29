USE SSISDB;
GO

DECLARE @DateSince DATE= GETDATE() - 14; -- number of days back
DECLARE @PackageName NVARCHAR(256) = 'PackageName.dtsx'

SELECT --distinct

              O.Operation_Id
            , E.Project_name                                AS Project_Name
            , EM.Package_Name
            , CONVERT(DATETIME, O.start_time)               AS Start_Time
            , CONVERT(DATETIME, O.end_time) AS End_Time
            , DATEDIFF(second, o.start_time, o.end_time)    AS duration_sec
            , DATEDIFF(minute, o.start_time, o.end_time)    AS duration_min
            , OM.message                                    AS [Error_Message]
            , EM.Event_Name
            , EM.Message_Source_Name                        AS Component_Name
            , EM.Subcomponent_Name                          AS Sub_Component_Name
            , E.Environment_Name
            , EM.Package_Path
            , E.Executed_as_name                            AS Executed_By
FROM 
            [SSISDB].[internal].[operations] AS O
JOIN        [SSISDB].[internal].[event_messages] AS EM      ON          EM.operation_id = O.operation_id
JOIN        [SSISDB].[internal].[operation_messages] AS OM  ON          EM.operation_id = OM.operation_id
JOIN        [SSISDB].[internal].[executions] AS E           ON          OM.Operation_id = E.EXECUTION_ID
WHERE 1 = 1
            AND o.start_time >= @DateSince
            AND em.event_name = 'OnError'
            AND OM.Message_Type = 120 -- Error 
            AND EM.package_name = @PackageName
            --AND EM.event_name = 'OnError'
            --AND om.message LIKE '%duplicate%'
            AND om.message LIKE '%deadlock%'
ORDER BY CONVERT(DATETIME, O.start_time) DESC;
