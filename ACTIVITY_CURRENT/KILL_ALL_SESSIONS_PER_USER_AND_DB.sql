DECLARE [mycursor] CURSOR FOR

-- Query for processes by login and database
SELECT [spid], [loginame] FROM [master]..[sysprocesses] 
WHERE 
--[loginame] = 'USERNAME' AND 
[dbid] = DB_ID('DBNAME');


OPEN [mycursor];

DECLARE @spid     INT
      , @loginame VARCHAR(255)
      , @cmd      VARCHAR(255);

-- Loop through the cursor, killing each process
FETCH NEXT FROM [mycursor]
INTO @spid
   , @loginame;
WHILE (@@FETCH_STATUS <> -1)
BEGIN
    SELECT @cmd = 'kill ' + CAST(@spid AS VARCHAR(5));
    EXEC (@cmd);
    PRINT CONCAT('Executed: ', @cmd)

    FETCH NEXT FROM [mycursor]
    INTO @spid
       , @loginame;
END;

CLOSE [mycursor];
DEALLOCATE [mycursor];
GO