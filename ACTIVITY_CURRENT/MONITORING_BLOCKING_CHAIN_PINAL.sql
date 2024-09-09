SET NOCOUNT ON;
GO
SELECT [R].[spid]
     , [R].[blocked]
     , REPLACE(REPLACE([T].[text], CHAR(10), ' '), CHAR(13), ' ') AS [BATCH]
INTO [#T]
FROM [sys].[sysprocesses] [R]
CROSS APPLY [sys].dm_exec_sql_text([R].[sql_handle]) [T];
GO
WITH [BLOCKERS] ([SPID], [BLOCKED], [LEVEL], [BATCH])
AS (SELECT [R].[spid]
         , [R].[blocked]
         , CAST(REPLICATE('0', 4 - LEN(CAST([R].[spid] AS VARCHAR))) + CAST([R].[spid] AS VARCHAR) AS VARCHAR(1000)) AS [LEVEL]
         , [R].[BATCH]
    FROM [#T] [R]
    WHERE ([R].[blocked] = 0 OR [R].[blocked] = [R].[spid])
    AND   EXISTS (SELECT * FROM [#T] [R2] WHERE [R2].[blocked] = [R].[spid] AND [R2].[blocked] <> [R2].[spid])
    UNION ALL
    SELECT [R].[spid]
         , [R].[blocked]
         , CAST([BLOCKERS].[LEVEL] + RIGHT(CAST((1000 + [R].[spid]) AS VARCHAR(100)), 4) AS VARCHAR(1000)) AS [LEVEL]
         , [R].[BATCH]
    FROM [#T] AS [R]
    INNER JOIN [BLOCKERS]
        ON [R].[blocked] = [BLOCKERS].[SPID]
    WHERE [R].[blocked] > 0
    AND   [R].[blocked] <> [R].[spid])
SELECT N'    ' + REPLICATE(N'|         ', LEN([BLOCKERS].[LEVEL]) / 4 - 1) + CASE
                                                                                 WHEN (LEN([BLOCKERS].[LEVEL]) / 4 - 1) = 0 THEN 'HEAD -  '
                                                                                 ELSE '|------  '
                                                                             END + CAST([BLOCKERS].[SPID] AS NVARCHAR(10)) + N' ' + [BLOCKERS].[BATCH] AS [BLOCKING_TREE]
FROM [BLOCKERS]
ORDER BY [BLOCKERS].[LEVEL] ASC;
GO
DROP TABLE [#T];
GO



USE [DBAAdmin];
GO


DECLARE @schema VARCHAR(MAX);
EXEC [dbo].[sp_WhoIsActive] @find_block_leaders = 1
                          , @sort_order = '[blocked_session_count] DESC'
                          , @show_sleeping_spids = 1
                          , @get_plans = 1
                          , @get_outer_command = 2
                          , @get_transaction_info = 2 -- bit
                          , @get_additional_info = 2
                          , @filter_type = 'login'
                          , @filter = 'DOMAIN\username';


SELECT [a].[loginame]
     , [a].[hostprocess]
     , [a].[spid]
     , [a].[program_name]
     , [d].[name]
     , [a].[cpu]
     , [a].[memusage]
     , [a].[physical_io]
     , *
FROM [master]..[sysprocesses] [a]
JOIN [sys].[databases] [d]
    ON [a].[dbid] = [d].[database_id]
WHERE EXISTS (
                 SELECT [b].* FROM [master]..[sysprocesses] [b] WHERE [b].[blocked] > 0 AND [b].[blocked] = [a].[spid]
             )
AND   NOT EXISTS (SELECT [b].* FROM [master]..[sysprocesses] [b] WHERE [b].[blocked] > 0 AND [b].[spid] = [a].[spid])
ORDER BY [a].[spid];