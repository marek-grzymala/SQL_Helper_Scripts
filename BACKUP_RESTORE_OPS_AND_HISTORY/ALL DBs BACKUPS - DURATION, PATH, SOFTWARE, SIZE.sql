SELECT
                bkset.database_name as databasename,
                bkset.backup_start_date as backupstartdate,
                bkset.backup_finish_date as backupenddate,
                datediff (minute, bkset.backup_start_date, bkset.backup_finish_date) as durationinmin,
                medfam.physical_device_name as backuppath,
                --medset.software_name as softwareusedforbackup,
                bkset.user_name as backuptakenby,
                --bkset.server_name as servername,

                case bkset.type
                                when 'L' then 'Transaction Log Backup'
                                when 'D' then 'Full Backup'
                                when 'F' then 'File Backup'
                                when 'I' then 'Differential Backup'
                                when 'G' then 'Differential Filebackup'
                                when 'P' then 'Partial Backup'
                                when 'Q' then 'Differential Partial Backup'
                                else null
                end as backuptype,

                cast((bkset.backup_size/1048576) as numeric(10,2)) as bckp_size_mb,
				--cast((bkset.compressed_backup_size/1048576) as numeric(10,2)) as compressed_size_mb,
				--cast(1-(bkset.compressed_backup_size/bkset.backup_size) as numeric(10,2))*100 AS [compr. %],

                bkset.first_lsn,
                bkset.last_lsn,
                bkset.database_backup_lsn, --log sequence number of the most recent full database backup.
                bkset.checkpoint_lsn,
                bkset.is_snapshot
				--,is_damaged

FROM
                msdb.dbo.backupset bkset
                left outer join msdb.dbo.backupmediaset medset 
                                on bkset.media_set_id = medset.media_set_id
                left outer join msdb.dbo.backupmediafamily medfam 
                                on medfam.media_set_id = medset.media_set_id

WHERE 
bkset.database_name IN ('YourDBNameHere') AND 
--bkset.type = 'D' AND
--and       
--      --put the date between which you want to find details of backup    
bkset.backup_finish_date > (DATEADD(DAY, -14, GETDATE())) --between '2016-01-03 05:31:30.000' and '2016-01-04 09:22:29.000'
--AND bkset.is_snapshot = 0
--AND medfam.physical_device_name NOT LIKE 'G:\Backup\%'

ORDER BY
                bkset.backup_finish_date DESC
