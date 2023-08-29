; WITH cte AS (SELECT 
DISTINCT 
database_name,
schema_name,
object_name,
server_principal_name,
statement,
additional_information
FROM sys.fn_get_audit_file ('F:\Path\AuditFileName.sqlaudit',default,default)
WHERE 
   ( [statement] LIKE 'INSERT%'
    OR [statement] LIKE 'MERGE%'
    OR [statement] LIKE 'UPDATE%' ) AND server_principal_name <> 'DOMAIN\username'
)SELECT 
    cte.database_name,
    cte.schema_name,
    cte.object_name,
    cte.server_principal_name,
    cte.statement,
    CAST(cte.additional_information AS XML)
FROM cte
GO 
