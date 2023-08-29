declare mycursor cursor
for

-- Query for processes by login and database
select spid, Loginame
from master..sysProcesses
where Loginame='AONNET\A0703134' and dbid=db_id('AON_MI_DWH')


open mycursor

declare @spid int, @loginame varchar(255), @cmd varchar(255)

-- Loop through the cursor, killing each process
Fetch NEXT FROM MYCursor INTO @spid, @loginame
While (@@FETCH_STATUS <> -1)
begin
    -- I don't really know why this is necasary, but it is.
    select @cmd = 'kill ' + cast(@spid as varchar(5))
    exec(@cmd)

    Fetch NEXT FROM MYCursor INTO @spid, @loginame
end

close mycursor
deallocate mycursor
go