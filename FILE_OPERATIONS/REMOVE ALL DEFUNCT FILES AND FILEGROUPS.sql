USE [YourDbName]
GO

DECLARE @sql_fl NVARCHAR(MAX), @sql_fg NVARCHAR(MAX);

WHILE EXISTS (
SELECT          TOP 1 fg.name
FROM            sys.filegroups fg
LEFT OUTER JOIN sysfilegroups sfg          ON fg.name = sfg.groupname
LEFT OUTER JOIN sysfiles f                 ON sfg.groupid = f.groupid
LEFT OUTER JOIN sys.allocation_units au    ON fg.data_space_id = au.data_space_id
WHERE           au.data_space_id IS NULL   AND f.name IS NOT NULL
)
BEGIN
	SELECT TOP 1
	               @sql_fl = 'ALTER DATABASE ' + QUOTENAME(DB_NAME()) + ' REMOVE FILE '     + QUOTENAME(f.name) + CHAR(13)+';',
	               @sql_fg = 'ALTER DATABASE ' + QUOTENAME(DB_NAME()) + ' REMOVE FILEGROUP '+ QUOTENAME(fg.name) + CHAR(13)+';'
	FROM            sys.filegroups fg
	LEFT OUTER JOIN sysfilegroups sfg          ON fg.name = sfg.groupname
	LEFT OUTER JOIN sysfiles f                 ON sfg.groupid = f.groupid
	LEFT OUTER JOIN sys.allocation_units au    ON fg.data_space_id = au.data_space_id
	WHERE           au.data_space_id IS NULL
	
	--EXEC(@sql_fl);
	--EXEC(@sql_fg);
	PRINT(@sql_fl);
	PRINT(@sql_fg);
END

