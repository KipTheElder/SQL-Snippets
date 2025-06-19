DROP TABLE IF EXISTS dbo.Stations;
CREATE TABLE dbo.Stations
    (StationId INT IDENTITY(1,1) PRIMARY KEY CLUSTERED,
     StationName VARCHAR(50),
     StationPhysicalOrder INT);

INSERT INTO dbo.Stations (StationName, StationPhysicalOrder)
    SELECT CHAR(64 + n), n
    FROM (VALUES
        (1),(2),(3),(4),(5),(6),(7),(8),(9),(10),(11),
        (12),(13),(14),(15),(16),(17),(18),(19)
    ) AS Numbers(n);

DROP TABLE IF EXISTS dbo.StationRoutingOverride;
CREATE TABLE dbo.StationRoutingOverride
    (StationRoutingOverrideId INT IDENTITY(1,1) PRIMARY KEY CLUSTERED,
     StationFromName VARCHAR(50),
     StationToName VARCHAR(50));

INSERT INTO dbo.StationRoutingOverride (StationFromName, StationToName)
    VALUES ('E', 'S'), ('B', 'I'), ('I', 'D');

/*
The required result is A, B, I, D, E, S

    VALUES ('F', 'S'), ('B', 'I'), ('I', 'J'), ('J', 'D')
For the above, it should be A, B, I, J, D, E, F, S

*/

WITH overrides AS 
(
 SELECT sro1.StationFromName, sro1.StationToName, s1.StationPhysicalOrder AS route_no, CAST(s1.StationPhysicalOrder + 0.1 AS DECIMAL(3, 1)) AS route_pos, s2.StationPhysicalOrder AS end_order
   FROM dbo.StationRoutingOverride sro1
   INNER JOIN dbo.Stations s1 ON s1.StationName = sro1.StationFromName
   INNER JOIN dbo.Stations s2 ON s2.StationName = sro1.StationToName
  WHERE NOT EXISTS
  (
   SELECT 1
     FROM dbo.StationRoutingOverride sro2
	WHERE sro2.StationToName = sro1.StationFromName
  )
 UNION ALL
 SELECT sro3.StationFromName, sro3.StationToName, sro4.route_no, CAST(sro4.route_pos + 0.1 AS DECIMAL(3, 1)), s.StationPhysicalOrder
   FROM dbo.StationRoutingOverride sro3
   INNER JOIN overrides sro4 ON sro3.StationFromName = sro4.StationToName
   INNER JOIN dbo.Stations s ON s.StationName = sro3.StationToName
),
     termini AS
(
 SELECT o.route_no AS first_stop,
        ROW_NUMBER() OVER (PARTITION BY CAST(o.route_pos AS INT) ORDER BY o.route_pos desc) AS row_no,
        s.StationPhysicalOrder AS last_stop
   FROM overrides o
   INNER JOIN dbo.Stations s ON s.StationName = o.StationToName
),
     ordered_route AS
(     
 SELECT s.StationName, s.StationPhysicalOrder
   FROM dbo.Stations s
  WHERE NOT EXISTS
  (
   SELECT 1
     FROM overrides o
	WHERE o.StationToName = s.StationName
  )
 UNION
 SELECT StationToName, route_pos
   FROM overrides
)
SELECT *
FROM ordered_route ord
LEFT OUTER JOIN termini t ON t.first_stop = ord.StationPhysicalOrder AND t.row_no = 1
WHERE NOT EXISTS
(
 SELECT 1
   FROM termini t2
  WHERE ord.StationPhysicalOrder > t2.first_stop AND ord.StationPhysicalOrder < t2.last_stop AND t2.row_no = 1
    AND CAST(ord.StationPhysicalOrder AS INT) <> t2.first_stop
)
ORDER BY ord.StationPhysicalOrder;