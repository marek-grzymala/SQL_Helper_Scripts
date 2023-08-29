USE [YourDbName]
GO

---------------------------------------------------------------
---- FIND THE FREE SPACE ON EACH FILE WITHIN A DATABASE: ------
---------------------------------------------------------------
; WITH cte AS (
SELECT 
                 [TYPE]           = a.TYPE_DESC
                ,[FILE_NAME]      = a.name
                ,[FILEGROUP_NAME] = fg.name
                ,[FILE_LOCATION]  = a.PHYSICAL_NAME
                ,[FILESIZE_KB]    = CONVERT(DECIMAL(10,2),    a.SIZE * 8)
                ,[FILESIZE_MB]    = CONVERT(DECIMAL(10,2),    a.SIZE/128.0)
                ,[USEDSPACE_KB]   = CONVERT(DECIMAL(10),      a.SIZE * 8 - ((SIZE * 8) - CAST(FILEPROPERTY(a.NAME, 'SPACEUSED') AS INT) * 8))
                ,[USEDSPACE_MB]   = CONVERT(DECIMAL(10),      a.SIZE/128.0 - ((SIZE/128.0) - CAST(FILEPROPERTY(a.NAME, 'SPACEUSED') AS INT)/128.0))
                ,[FREESPACE_MB]   = CONVERT(DECIMAL(10,2),    a.SIZE/128.0 - CAST(FILEPROPERTY(a.NAME, 'SPACEUSED') AS INT)/128.0)
                ,[FREESPACE_%]    = CONVERT(DECIMAL(10,2),  ((a.SIZE/128.0 - CAST(FILEPROPERTY(a.NAME, 'SPACEUSED') AS INT)/128.0)/(a.SIZE/128.0))*100)
                ,[AUTOGROW]       = 'By ' + CASE is_percent_growth WHEN 0 THEN CAST(growth/128 AS VARCHAR(10)) + ' MB -' 
                                            WHEN 1 THEN CAST(growth AS VARCHAR(10)) + '% -' ELSE '' END 
                                          + CASE max_size WHEN 0 THEN 'DISABLED' WHEN -1 THEN ' Unrestricted' 
                                            ELSE ' Restricted to ' + CAST(max_size/(128 * 1024) AS VARCHAR(10)) + ' GB' END 
                                          + CASE is_percent_growth WHEN 1 THEN ' [autogrowth by percent, BAD setting!]' ELSE '' END
FROM 
                sys.filegroups fg 
LEFT OUTER JOIN sys.database_files a ON A.data_space_id = fg.data_space_id
)
SELECT
                --'DBCC SHRINKFILE ('+cte.[FILE_NAME]+', '+CAST([USEDSPACE_KB] AS VARCHAR(32))+');'
                CONCAT('DBCC SHRINKFILE ([', cte.[FILE_NAME], '], ', IIF([USEDSPACE_MB] = 0, 1, [USEDSPACE_MB]), ');
                ALTER DATABASE [', DB_NAME(), '] MODIFY FILE ( NAME = N''', cte.[FILE_NAME], ''', FILEGROWTH = 1024KB );') AS [ShrinkCommand]
FROM            cte
ORDER BY        [TYPE] DESC, [FILE_NAME];


---------------------------------------------------------------
---- SHRINK FILES TO REDUCE UNUSED SPACE:               -------
---------------------------------------------------------------

/*
CHECKPOINT;
GO

DBCC DROPCLEANBUFFERS;
GO

DBCC FREEPROCCACHE;
GO

DBCC FREESYSTEMCACHE ('ALL');
GO

DBCC FREESESSIONCACHE
GO

*/

USE [YourDbName]
GO
DBCC SHRINKFILE (tempdevXX, 16384); --SIZE IN MB
GO