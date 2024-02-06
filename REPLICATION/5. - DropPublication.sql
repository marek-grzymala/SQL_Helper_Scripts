-- Dropping the transactional articles
USE [test_db]
GO

EXEC [sys].[sp_dropsubscription] @publication = N'test_db_pub_a'
                               , @article = N'test_table_01'
                               , @subscriber = N'all'
                               , @destination_db = N'all';
GO
USE [test_db];
EXEC [sys].[sp_droparticle] @publication = N'test_db_pub_a'
                          , @article = N'test_table_01'
                          , @force_invalidate_snapshot = 1;
GO

-- Dropping the transactional publication
USE [test_db];
EXEC [sys].[sp_droppublication] @publication = N'test_db_pub_a';
GO
