USE [DWHSupport_Audit]
GO
/****** Object:  Table [qv].[TempTable]    Script Date: 12/07/2019 10:34:42 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [qv].[TempTable](
	[LogID] [bigint] NOT NULL,
	[SystemKey] [int] NOT NULL,
	[RunID] [bigint] NOT NULL,
	[ProcessStartTime] [varchar](19) NULL,
	[ProcessEndTime] [varchar](19) NULL,
	[ProcessDuration] [time](0) NULL,
	[ProcessDurationSec] [bigint] NULL,
	[Start_TimeOnly] [time](7) NULL,
	[End_TimeOnly] [time](7) NULL,
	[InsertCount] [bigint] NULL,
	[UpdateCount] [bigint] NULL,
	[DeleteCount] [bigint] NULL
) ON [PRIMARY]
GO
