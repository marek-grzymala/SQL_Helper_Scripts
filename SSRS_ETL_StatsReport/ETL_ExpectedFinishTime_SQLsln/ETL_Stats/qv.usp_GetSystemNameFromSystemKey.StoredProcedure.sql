USE [DWHSupport_Audit]
GO
/****** Object:  StoredProcedure [qv].[usp_GetSystemNameFromSystemKey]    Script Date: 12/07/2019 10:34:43 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [qv].[usp_GetSystemNameFromSystemKey] @SystemKey INT, @SystemName VARCHAR(32) OUTPUT
AS
BEGIN
SELECT @SystemName = 

      CONCAT((s.[systemname]), 
      CASE s.[systemname]
		WHEN 'eGlobal' THEN CONCAT('_', s.[systemcountrycode])
		WHEN 'Xpress' THEN CONCAT('_', s.[systemcountrycode])
		WHEN 'MGA' THEN CONCAT('_', s.[systemcountrycode])
		WHEN 'BMW' THEN CONCAT('_', s.[systemcountrycode])
	  ELSE '' END)
	  
FROM [DWHSupport_Audit].[qv].[dim_aon_system] s
WHERE
	s.[dim_aon_system_key] = @SystemKey
END
GO
