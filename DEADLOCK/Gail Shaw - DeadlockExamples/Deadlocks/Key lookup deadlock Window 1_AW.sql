USE DMOperations
GO


SET LOCK_TIMEOUT 300000 -- 5 minutes

-- basic key-lookup deadlock window 1

--Run this then switch to window 2 and run that code

SELECT * FROM [DMOperations].[dbo].[DMSSR_Deadlock_details_AndreasWolter] WITH (UPDLOCK) WHERE DatabaseName_1 LIKE 'JobScheduler%'
GO 100