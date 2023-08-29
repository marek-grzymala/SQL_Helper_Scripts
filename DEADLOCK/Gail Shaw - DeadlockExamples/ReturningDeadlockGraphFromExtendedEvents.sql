/*Listing 1: Returning the deadlock graph from the system_health event session*/
/*Original author: Jonathan Kehayias, http://www.sqlskills.com/blogs/jonathan/ */

-- ring_buffer target
SELECT  XEvent.query('(event/data/value/deadlock)[1]') AS DeadlockGraph
FROM    ( SELECT    XEvent.query('.') AS XEvent
          FROM      ( SELECT    CAST(target_data AS XML) AS TargetData
                      FROM      sys.dm_xe_session_targets st
                                JOIN sys.dm_xe_sessions s 
                                 ON s.address = st.event_session_address
                      WHERE     s.name = 'system_health'
                                AND st.target_name = 'ring_buffer'
                    ) AS Data
                    CROSS APPLY
                     TargetData.nodes
                      ('RingBufferTarget/event[@name="xml_deadlock_report"]')
                    AS XEventData ( XEvent )
        ) AS src; 
GO

-- event file target
SELECT  XEvent.query('(event/data[@name="xml_report"]/value/deadlock)[1]') AS DeadlockGraph
FROM    ( SELECT    XEvent.query('.') AS XEvent
          FROM      (   -- Cast the target_data to XML 
                      SELECT    CAST(event_data AS XML) AS TargetData
                      FROM      sys.fn_xe_file_target_read_file('system_health*xel',
                                                              'Not used in 2012',
                                                              NULL, NULL)
                    ) AS Data -- Split out the Event Nodes 
                    CROSS APPLY TargetData.nodes('event[@name="xml_deadlock_report"]')
                    AS XEventData ( XEvent )
        ) AS src;
GO

