-- IMPORTANT!!!! 
-- IF THE SQL SERVICE ACCOUNT DOES NOT HAVE PERMISSIONS TO READ IN @_key = N'SOFTWARE\Microsoft\MSSQLServer\MSSQLServer\SuperSocketNetLib\AdminConnection\Tcp'
-- THEN OPEN REGEDIT AND GRANT FULL PERMISSIONS TO THAT ACCOUNT
-- OTHERWISE YOU GET Access Denied error message !!!

SET NOCOUNT ON;

DECLARE @_key                    NVARCHAR(2000) = N'SOFTWARE\Microsoft\MSSQLServer\MSSQLServer\SuperSocketNetLib\AdminConnection\Tcp'
      , @TcpDynamicPortsExpected INT            = 1434
      , @TcpDynamicPortsActual   INT;

DECLARE @RegEntries TABLE 
(
	[RegEntryName] VARCHAR(255)
  , [RegValue] VARCHAR(255)
)

INSERT @RegEntries EXEC master..xp_instance_regenumvalues @rootkey = N'HKEY_LOCAL_MACHINE', @key = @_key;
SELECT @TcpDynamicPortsActual = [RegValue] FROM @RegEntries WHERE [RegEntryName] = 'TcpDynamicPorts'
--SELECT @TcpDynamicPortsActual

IF (@TcpDynamicPortsExpected = CONVERT(INT, @TcpDynamicPortsActual))
BEGIN
    PRINT ('OK')
END
ELSE
BEGIN
    PRINT ('No Good')
END