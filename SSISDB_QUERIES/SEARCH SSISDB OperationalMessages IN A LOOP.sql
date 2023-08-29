USE SSISDB
GO

DECLARE @message NVARCHAR(256) = '%NT AUTHORITY\ANONYMOUS%'
DECLARE @DateSince DATETIME = DATEADD(MINUTE, -1, GETDATE())

DECLARE @counter INT = 1, @RowCount INT
DECLARE @Msg VARCHAR(200)

WHILE (@counter <= 40)
BEGIN
SELECT 1
FROM                [SSISDB].[internal].[operations] (NOLOCK) AS O
INNER JOIN          [SSISDB].[internal].[operation_messages] (NOLOCK) AS OM ON O.operation_id = OM.operation_id
INNER JOIN          [SSISDB].[internal].[executions] (NOLOCK) AS EX ON O.Operation_id = EX.execution_id
WHERE 1 = 1
AND                 O.start_time > @DateSince
AND                 OM.[message] LIKE @message

SELECT @RowCount = @@ROWCOUNT
SELECT @Msg = 'Processing Loop Number: '+CAST(@counter AS VARCHAR(10))+', '+CAST(@RowCount AS VARCHAR(10)) + ' rows affected'
RAISERROR (@Msg, 0, -1) WITH NOWAIT

IF (@RowCount > 0)
BEGIN
    SELECT @Msg = CONCAT('Loop Number: ', CAST(@counter AS VARCHAR(10)), ' Found ', CAST(@RowCount AS VARCHAR(10)), ' Error Records')
    RAISERROR (@Msg, 18, -1) WITH NOWAIT, LOG
    BREAK;
END

WAITFOR DELAY '00:10:00'
SET @counter = @counter + 1
END