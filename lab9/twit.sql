-- Code by Kazuto Nishimori (kazuto-nishimori.github.io) Supplement to kazuto-nishimori.github.io/lab9




--First of all, I will add a projectin that is appropriate for the analysis using this following code borrowed from spatialreference.org

INSERT into spatial_ref_sys (srid, auth_name, auth_srid, proj4text, srtext) values ( 102004, 'esri', 102004, '+proj=lcc +lat_1=33 +lat_2=45 +lat_0=39 +lon_0=-96 +x_0=0 +y_0=0 +ellps=GRS80 +datum=NAD83 +units=m +no_defs ', 'PROJCS["USA_Contiguous_Lambert_Conformal_Conic",GEOGCS["GCS_North_American_1983",DATUM["North_American_Datum_1983",SPHEROID["GRS_1980",6378137,298.257222101]],PRIMEM["Greenwich",0],UNIT["Degree",0.017453292519943295]],PROJECTION["Lambert_Conformal_Conic_2SP"],PARAMETER["False_Easting",0],PARAMETER["False_Northing",0],PARAMETER["Central_Meridian",-96],PARAMETER["Standard_Parallel_1",33],PARAMETER["Standard_Parallel_2",45],PARAMETER["Latitude_Of_Origin",39],UNIT["Meter",1],AUTHORITY["EPSG","102004"]]');

--Add geometry columns to the tweet tables.
select addgeometrycolumn('novembertweets', 'geom', 102004, 'point', 2);
UPDATE  novembertweets
SET geom = st_transform (st_setsrid(st_makepoint(lng,lat),4326),102004);
Run the same exact code with dorian tweets


--Add geom to counties. Then remove counties outside of Eastern US
select addgeometrycolumn('uscounties', 'geom', 102004, 'multipolygon', 2);
UPDATE  uscounties
SET geom = st_transform(geometry,102004);
alter table uscounties
drop column geometry
SELECT populate_geometry_columns('uscounties'::regclass);
DELETE FROM uscounties
WHERE statefp NOT IN ('54', '51', '50', '47', '45', '44', '42', '39', '37', '36', '34', '33', '29', '28', '25', '24', '23', '22', '21', '18', '17', '13', '12', '11', '10', '09', '05', '01');

-- Add a GEOID column to november tweets to signify the county in which it resides
ALTER TABLE novembertweets
ADD COLUMN geoid varchar(5);  
UPDATE novembertweets
SET geoid= uscounties.geoid
from uscounties 
where st_intersects (novembertweets.geom, uscounties.geom);
SELECT count(status_id), geoid
FROM novembertweets 
where geoid is not null 
GROUP BY geoid

-- Add a GEOID column to dorian tweets to signify the county in which it resides
ALTER TABLE doriantweets
ADD COLUMN geoid varchar(5);  
UPDATE doriantweets
SET geoid= uscounties.geoid
from uscounties 
where st_intersects (doriantweets.geom, uscounties.geom);
SELECT count(status_id), geoid
FROM doriantweets 
where geoid is not null 
GROUP BY geoid

-- Add and populate columns for tweet counts for Nov and Dorian
ALTER TABLE uscounties
ADD COLUMN  doriancount varchar(5); 
ALTER TABLE uscounties
ADD COLUMN novembercount varchar(5);
UPDATE uscounties 
SET doriancount = a 
from (SELECT count(status_id) as a, geoid
FROM doriantweets 
where geoid is not null 
GROUP BY geoid) as ct
where uscounties.geoid = ct.geoid

UPDATE uscounties 
SET novembercount = 0;
UPDATE uscounties 
SET novembercount = a
from (SELECT count(status_id) as a, geoid
FROM novembertweets 
where geoid is not null 
GROUP BY geoid) as ct
where uscounties.geoid = ct.geoid

--Calculate tweet rate and normalized difference index
ALTER TABLE uscounties
ADD COLUMN twrate float;
ALTER TABLE uscounties
ADD COLUMN ndti float;
UPDATE uscounties 
SET twrate = cast(doriancount as float) * 10000 / cast(pop as float);
UPDATE uscounties 
SET ndti = (cast(doriancount as float) - cast(novembercount as float))/((cast(doriancount as float) + cast(novembercount as float) )*1.0)
where (cast(doriancount as float) + cast(novembercount as float) ) > 0;
UPDATE uscounties 
SET ndti = 0 where ndti is NULL




-- convert counties to centroid
CREATE VIEW countiescentroids AS
SELECT geoid, st_centroid(wkb_geometry) AS geom, pp_val
FROM countieseastg

-- Create state boundary
CREATE TABLE usstates AS
SELECT statefp,
  	   ST_Union(geom) as geom
FROM uscounties
GROUP BY statefp
select addgeometrycolumn('usstates', 'geometry', 102004, 'multipolygon', 2);