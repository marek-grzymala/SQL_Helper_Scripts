USE [TestDb]
GO


/* Full List: */
SELECT      DISTINCT
            so.type
           ,so.type_desc
           ,so.object_id
           ,sch.name AS [SchemaName]
           ,so.name  AS [ObjectName]
FROM        sys.objects     so 
INNER JOIN  sys.syscomments sc  ON sc.id         = so.object_id
INNER JOIN  sys.schemas     sch ON sch.schema_id = so.schema_id
WHERE       1 = 1
AND         sc.encrypted = 1
AND         so.type IN 
            (
                 'P'    /* Stored procedure */
                ,'V'    /* View */
                ,'TR'   /* Trigger */
                ,'FN'   /* Scalar function */
                ,'TF'   /* Table-function */
                ,'IF'   /* In-lined table-function */
                --,'D'    /* Default Constarint */
                --,'R'    /* Rule */
            )

/* Count Per Type: */
SELECT      
            o.type,
            o.type_desc,
            COUNT(DISTINCT o.object_id) as [CountPerType]
FROM        sys.objects o --ON  s.object_id = o.object_id
INNER JOIN  sys.syscomments sc ON sc.id = o.object_id
WHERE       1 = 1
AND         sc.encrypted = 1
AND         o.type IN 
            (
                 'P'    /* Stored procedure */
                ,'V'    /* View */
                ,'TR'   /* Trigger */
                ,'FN'   /* Scalar function */
                ,'TF'   /* Table-function */
                ,'IF'   /* In-lined table-function */
                --,'D'    /* Default Constarint */
                --,'R'    /* Rule */
            )
GROUP BY    o.type, o.type_desc
ORDER BY    [CountPerType] DESC

/* Procedures only: */
SELECT * FROM sys.procedures
WHERE OBJECTPROPERTY([object_id], 'IsEncrypted') = 1;