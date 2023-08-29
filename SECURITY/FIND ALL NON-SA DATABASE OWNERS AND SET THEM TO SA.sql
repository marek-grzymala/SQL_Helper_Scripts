SELECT 
		[name]
	  , SUSER_SNAME([owner_sid]) AS [DBOwnerName] 
FROM	[master].[sys].[databases]
--WHERE suser_sname( owner_sid ) <> 'sa';

ALTER AUTHORIZATION ON DATABASE::[YourDbName] TO [sa];