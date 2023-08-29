--USE [YourDbName]
--GO

SELECT      
            so.[object_id]            AS [object_id],
            so.[type]                 AS [obj type],
            ss.[name]                 AS [schema],
            so.[name]                 AS [name],
            tr.[TriggerOnSchema],
            tr.[TriggerOnTable]
            
FROM        sys.objects  AS so
INNER JOIN  sys.schemas  AS ss  ON ss.[schema_id] = so.[schema_id]
OUTER APPLY ( 
            SELECT      sch.[name]                AS [TriggerOnSchema],
                        OBJECT_NAME(tr.parent_id) AS [TriggerOnTable]
            
            FROM        sys.triggers AS tr  
            LEFT  JOIN  sys.tables   AS st  ON tr.[parent_id] = st.[object_id]
            LEFT  JOIN  sys.schemas  AS sch ON so.[schema_id] = sch.[schema_id]
            WHERE tr.[object_id] = so.[object_id]
            ) AS [tr]
WHERE       OBJECTPROPERTY(so.[object_id], 'IsEncrypted') = 1
ORDER BY    so.[object_id];


--EXECUTE [dbo].[_usp_DecryptEncryptedObject] 
--@EncryptedObjectOwnerOrSchema = 'dbo', 
--@EncryptedObjectName = N'p_TestEncryption',
--@CreateDecryptedVersion = 1,
--@PrintOutObjectDefinition = 0; --'sp_sel_member_accts_for_penpay'