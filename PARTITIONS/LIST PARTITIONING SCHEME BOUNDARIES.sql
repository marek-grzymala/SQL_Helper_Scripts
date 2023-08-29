
SELECT      
            sps.data_space_id AS [DataSpaceID]
           ,sps.name          AS [PartSchName]
           ,spf.name          AS [PartitionFunction]
           ,CASE 
                WHEN spf.fanout < (
                                    SELECT COUNT(*) FROM sys.destination_data_spaces sdd 
                                    WHERE sps.data_space_id = sdd.partition_scheme_id
                                  ) 
                THEN (
                      SELECT sf.name 
                      FROM   sys.filegroups sf, sys.destination_data_spaces sdd 
                      WHERE  sf.data_space_id  = sdd.data_space_id 
                      AND    sps.data_space_id = sdd.partition_scheme_id AND sdd.destination_id > spf.fanout
                     ) 
                ELSE NULL 
            END AS [NextUsedFileGroup]
FROM        sys.partition_schemes   AS sps
INNER JOIN  sys.partition_functions AS spf ON sps.function_id = spf.function_id 
--WHERE       (sps.name = N'ps_daily_date')

SELECT      sdd.destination_id          AS [DestDataSpaceID]
           ,sdd.data_space_id
           ,sfg.name                    AS [FileGroupName]
FROM        sys.partition_schemes       AS sps
INNER JOIN  sys.partition_functions     AS spf ON sps.function_id = spf.function_id 
INNER JOIN  sys.destination_data_spaces AS sdd ON sdd.partition_scheme_id = sps.data_space_id and sdd.destination_id <= spf.fanout
INNER JOIN  sys.filegroups              AS sfg ON sfg.data_space_id = sdd.data_space_id
--WHERE       (sps.name = N'ps_daily_date')
ORDER BY    [DestDataSpaceID] ASC