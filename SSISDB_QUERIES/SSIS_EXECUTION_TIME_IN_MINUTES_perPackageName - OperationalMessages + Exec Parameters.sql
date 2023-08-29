USE SSISDB
GO

DECLARE @Operation_Id BIGINT = 8 --11893152 -- <== SSISDB.internal.execution_info.execution_id
DECLARE @message NVARCHAR(256) = '%NT AUTHORITY\ANONYMOUS%'
DECLARE @DateSince DATETIME = DATEADD(DAY, -12, GETDATE())

SELECT --DISTINCT 

      --CAST(O.start_time AS DATETIME2(0)) AS [StartTime]
      --, CAST(O.end_time AS DATETIME2(0)) AS [EndTime]
      CAST(OM.message_time AS DATETIME2(0)) AS [MessageTime]
      --, EX.Project_name                AS [ProjectName]
      --, EX.Package_Name
      --, EX.executed_as_name
      --, O.Operation_Id
      --, OM.operation_message_id
      , epv.parameter_name
	  , epv.parameter_value

      , DATEDIFF(MINUTE, LAG(OM.message_time) OVER (ORDER BY OM.message_time), OM.message_time) AS [DurationMinutes] 
      , OM.message
      , CASE O.status 
          WHEN 1 THEN 'Created'
          WHEN 2 THEN 'Running'
          WHEN 3 THEN 'Cancelled'
          WHEN 4 THEN 'Failed'
          WHEN 5 THEN 'About to run'
          WHEN 6 THEN 'Ended unexpectedly'
          WHEN 7 THEN 'Success'
          WHEN 8 THEN 'Stopping'
          WHEN 9 THEN 'Completed'
          ELSE 'Unknown'
        END AS [Status]
      , DATEDIFF(SECOND, O.start_time, O.end_time) AS duration_sec
      , DATEDIFF(MINUTE, O.start_time, O.end_time) AS duration_min


FROM                [SSISDB].[internal].[operations] (NOLOCK) AS O
--INNER JOIN          [SSISDB].[internal].[event_messages] (NOLOCK) AS EM ON O.operation_id = O.operation_id
INNER JOIN          [SSISDB].[internal].[operation_messages] (NOLOCK) AS OM ON O.operation_id = OM.operation_id
INNER JOIN          [SSISDB].[internal].[executions] (NOLOCK) AS EX ON O.Operation_id = EX.execution_id
INNER JOIN			[SSISDB].[internal].[execution_parameter_values] AS epv ON epv.execution_id = EX.execution_id

      
WHERE 1 = 1
AND                 O.Operation_Id = @Operation_Id
AND                 O.start_time >= @DateSince
--AND                 OM.[message] LIKE @message

ORDER BY OM.message_time DESC
            --O.operation_id DESC, OM.operation_message_id DESC
