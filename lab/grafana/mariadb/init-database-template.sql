CREATE OR REPLACE DATABASE infrastructure_telemetry;

USE infrastructure_telemetry;

CREATE OR REPLACE TABLE tests(
   start       TIMESTAMP    NOT NULL
  ,finish      TIMESTAMP    NOT NULL
  ,id          VARCHAR(65)  NOT NULL
  ,description VARCHAR(255) NOT NULL
  ,result      SMALLINT     NOT NULL CHECK(result IN (0,1))
  ,log         VARCHAR(255)
);

INSERT INTO tests
  (start, finish, id, description, result, log)
VALUES
   ('2022-01-20 23:55:00','2022-01-20 23:57:00','wasp-sandbox-1_01.001','Deploy NGINX with 1 replica',0,null)
  ,('2022-01-20 23:56:00','2022-01-20 23:56:02','wasp-sandbox-1_01.002','Scale NGINX Deployment from 1 to 70 replicas and Cluster Scale UP',0,null)
  ,('2022-01-20 23:57:11','2022-01-20 23:57:29','wasp-sandbox-1_01.003','Scale NGINX Deployment from 70 to 1 replica and Cluster Scale DOWN',0,null)
;

CREATE OR REPLACE USER 'grafana_reader'@'%' IDENTIFIED BY "GRAFANA_READER_PASSWORD";

GRANT SELECT ON infrastructure_telemetry.* TO 'grafana_reader'@'%';

GRANT SELECT, SHOW DATABASES, CREATE TEMPORARY TABLES, SHOW VIEW ON *.* TO 'grafana_reader'@'%' WITH GRANT OPTION;

/*
SELECT user(), current_user();
SHOW GRANTS FOR 'grafana_reader'@'%';
SELECT table_name FROM information_schema.tables WHERE table_schema = database() ORDER BY table_name;
*/
