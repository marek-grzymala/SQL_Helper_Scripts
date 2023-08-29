SELECT
    rh.destination_database_name as 'Database Name',
    rh.[user_name] as 'Username',
    CASE rh.restore_type
        WHEN NULL THEN 'NULL'
        WHEN 'D' THEN 'Database'
        WHEN 'F' THEN 'File'
        WHEN 'G' THEN 'Filegroup'
        WHEN 'I' THEN 'Differential'
        WHEN 'L' THEN 'Log File'
        WHEN 'V' THEN 'Verifyonly'
        WHEN 'R' THEN 'Revert'
    END as 'Restore Type',
    --CASE rh.[replace]
    --    WHEN NULL THEN 'NULL'
    --    WHEN 1 THEN 'YES'
    --    WHEN 0 THEN 'NO'
    --END AS 'Database Replaced',
    rh.restore_date as 'Date Restored',
    rfg.[filegroup_name],
    rf.file_number,
    --rf.destination_phys_drive,
    rf.destination_phys_name,
	b.[database_name] AS [Source Database],
	b.backup_start_date,
	b.backup_finish_date
FROM msdb..restorehistory rh
inner join msdb..restorefilegroup rfg 
    on rh.restore_history_id = rfg.restore_history_id
inner join msdb..restorefile rf
    on rh.restore_history_id = rf.restore_history_id
inner join
	msdb.dbo.backupset b on b.backup_set_id = rh.backup_set_id

order by rh.restore_date desc
