SET QUOTED_IDENTIFIER ON
SET ANSI_NULLS ON
GO

--
-- Name:    
--          sp_droparticle
--          
-- Description: 
--          Drops an article from a snapshot or transactional publication.
--			An article cannot be removed if one or more subscriptions to it exist.
--			This stored procedure is executed at the Publisher on the publication database.
--  
-- Security: 
--          Public
--
-- Returns:
--          Success (0) or Failure (1)
--      
-- Owner:   
--          <current owner> 

--create procedure sys.sp_droparticle
--(
--    @publication				sysname,
--    @article					sysname,
--    @ignore_distributor			bit = 0,    
--    @force_invalidate_snapshot	bit = 0,
--    @publisher					sysname = NULL,
--    @from_drop_publication		bit = 0
--)
--AS
--BEGIN

	DECLARE @publication SYSNAME = 'test_db_pub_a', @article SYSNAME = 'test_table_01' 
	
	DECLARE
    
    @ignore_distributor			bit = 0,    
    @force_invalidate_snapshot	bit = 0,
    @publisher					sysname = NULL,
    @from_drop_publication		bit = 0

	
	DECLARE @cmd			nvarchar(4000)
	DECLARE @retcode		int
	DECLARE @publisher_type	sysname

	SET @retcode = 0
	
	--EXEC @retcode = sys.sp_MSrepl_getpublisherinfo	@publisher		= @publisher,
	--												@rpcheader		= @cmd OUTPUT,
	--												@publisher_type	= @publisher_type OUTPUT
	

	-- Add sp
	SET @publisher = UPPER(@publisher) COLLATE DATABASE_DEFAULT
	set @cmd = N'sys.sp_MSrepl_droparticle'
	
	EXEC @retcode = @cmd
					@publication,
					@article,
					@ignore_distributor,
					@force_invalidate_snapshot,
					@publisher,
					@from_drop_publication,
					@publisher_type

--DECLARE @publication SYSNAME = 'test_db_pub_a', @article SYSNAME = 'test_table_01' 

--EXEC 'sys.sp_MSrepl_droparticle' @publication, @article

--	RETURN (@retcode)
--END
--GO