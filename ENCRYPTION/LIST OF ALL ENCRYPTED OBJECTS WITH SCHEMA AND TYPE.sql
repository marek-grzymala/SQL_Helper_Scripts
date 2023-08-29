USE [TestDb]
GO


SELECT      DISTINCT
            sso.[id]   AS [ObjectId],
            sso.[type] AS [ObjectType],
            CASE sso.[type]
               WHEN 'P'       THEN 'PROCEDURE'
               WHEN 'V'       THEN 'VIEW'
               WHEN 'FN'      THEN 'FUNCTION'
               WHEN 'IF'      THEN 'TABLE-VALUED FUNCTION'
               WHEN 'TR'      THEN 'TRIGGER'
               ELSE sso.[type]
            END               AS [ObjectType], 
            sch.[name] AS [SchemaName],
            sso.[name] AS [ObjectName]
FROM        sys.sysobjects  sso
INNER JOIN  sys.objects so ON so.object_id = sso.id
INNER JOIN  sys.schemas sch ON sch.schema_id = so.schema_id
INNER JOIN  sys.syscomments sc  ON sso.id = sc.id
WHERE       sc.[encrypted] = 1

ORDER BY sso.[id]