SELECT [dxp].[name] AS [Package]
     , [dxo].[name] AS [EventName]
     , [dxo].[capabilities_desc] AS [Capabilities]
     , [dxo].[description] AS [Description]
FROM [sys].[dm_xe_packages] AS [dxp]
INNER JOIN [sys].[dm_xe_objects] AS [dxo]
    ON [dxp].[guid] = [dxo].[package_guid]
WHERE [dxo].[object_type] = 'event'
AND [dxo].[description] LIKE '%deadlock%'
ORDER BY [Package]
       , [EventName];