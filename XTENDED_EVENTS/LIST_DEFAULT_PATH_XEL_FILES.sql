; -- Previous statement must be properly terminated
WITH xeTargets
AS
(
    SELECT
        s.name
        , t.target_name
        , CAST(t.target_data AS xml) AS xmlData
    FROM
        sys.dm_xe_session_targets AS t
        JOIN sys.dm_xe_sessions AS s
            ON s.address = t.event_session_address
)
SELECT
    xt.name
    , xt.target_name
    , xNodes.xNode.value('@name', 'varchar(250)') AS filePath
    , xt.xmlData
FROM xeTargets AS xt
OUTER APPLY xt.xmlData.nodes('.//File') xNodes (xNode) /* OUTER APPLY if you want to see other sessions */