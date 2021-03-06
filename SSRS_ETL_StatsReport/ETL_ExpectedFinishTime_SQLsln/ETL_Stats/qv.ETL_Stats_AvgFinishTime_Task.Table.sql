USE [DWHSupport_Audit]
GO
/****** Object:  Table [qv].[ETL_Stats_AvgFinishTime_Task]    Script Date: 12/07/2019 10:34:40 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [qv].[ETL_Stats_AvgFinishTime_Task](
	[SystemKey] [int] NOT NULL,
	[TimeRecorded] [datetime] NOT NULL,
	[ProcessName] [nvarchar](256) NOT NULL,
	[7-DayAverage] [time](7) NULL,
	[14-DayAverage] [time](7) NULL,
	[30-DayAverage] [time](7) NULL,
 CONSTRAINT [PK_ETL_Stats_AvgFinishTime_Task] PRIMARY KEY CLUSTERED 
(
	[SystemKey] ASC,
	[TimeRecorded] ASC,
	[ProcessName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100) ON [PRIMARY]
) ON [PRIMARY]
GO
