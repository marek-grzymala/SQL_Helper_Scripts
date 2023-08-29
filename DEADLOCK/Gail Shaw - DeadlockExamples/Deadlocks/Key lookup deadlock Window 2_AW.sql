USE DMOperations
GO

SET LOCK_TIMEOUT 300000


-- basic key-lookup deadlock window 2

BEGIN TRANSACTION
 UPDATE [dbo].[DMSSR_Deadlock_details_AndreasWolter] SET DatabaseName_1 = DatabaseName_1 + '_ABC'
 WHERE [ProcedureName_1] = 'adhoc'
ROLLBACK

GO 100
