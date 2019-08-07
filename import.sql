/* ----------------------------------------------------------------------
 *
 * Load XML data from the Stack Exchange data dump, which is Creative Commons
 * https://archive.org/details/stackexchange
 *
 * Remember you need to enable local LOAD INFILE commands with the `local_infile=ON` option in /etc/my.cnf
 * and also use the same option with the client:
 *
 * mysql --local-infile < Base.sql
 */

CREATE DATABASE IF NOT EXISTS sample_rep;
USE sample_rep;

DROP TABLE IF EXISTS sample_rep.REPLACEMEPostTags;
DROP TABLE IF EXISTS sample_rep.REPLACEMETags;
DROP TABLE IF EXISTS sample_rep.VotesXml;
DROP TABLE IF EXISTS sample_rep.REPLACEMEVotes;
DROP TABLE IF EXISTS sample_rep.REPLACEMEPostHistory;
DROP TABLE IF EXISTS sample_rep.REPLACEMEComments;
DROP TABLE IF EXISTS sample_rep.REPLACEMEPosts;
DROP TABLE IF EXISTS sample_rep.BadgesXml;
DROP TABLE IF EXISTS sample_rep.REPLACEMEBadges;
DROP TABLE IF EXISTS sample_rep.REPLACEMEBadgeTypes;
DROP TABLE IF EXISTS sample_rep.REPLACEMEUsers;

SET @DATETIME_ISO8601 = '%Y-%m-%dT%H:%i:%s.%f';

/* ---------------------------------------------------------------------- */

CREATE TABLE REPLACEMEUsers (
  Id               INT AUTO_INCREMENT PRIMARY KEY,
  Reputation       INT UNSIGNED NOT NULL DEFAULT 1,
  CreationDate     DATETIME NOT NULL,
  DisplayName      TINYTEXT NOT NULL,
  LastAccessDate   DATETIME NOT NULL,
  WebsiteUrl       VARCHAR(200) NULL,
  Location         TINYTEXT,
  Age              TINYINT UNSIGNED NULL,
  AboutMe          TEXT NULL,
  Views            INT UNSIGNED NOT NULL DEFAULT 0,
  UpVotes          INT UNSIGNED NOT NULL DEFAULT 0,
  DownVotes        INT UNSIGNED NOT NULL DEFAULT 0
);

LOAD XML LOCAL INFILE 'Users.xml' INTO TABLE REPLACEMEUsers
(Id, Reputation, @CreationDate, DisplayName, @LastAccessDate, WebsiteUrl, Location, Age, AboutMe, Views, UpVotes, DownVotes)
SET CreationDate = STR_TO_DATE(@CreationDate, @DATETIME_ISO8601),
    LastAccessDate = STR_TO_DATE(@LastAccessDate, @DATETIME_ISO8601);

ANALYZE TABLE REPLACEMEUsers;

/* ---------------------------------------------------------------------- */

CREATE TABLE BadgesXml (
  Id               INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  UserId           INT NOT NULL,
  Name             TINYTEXT NOT NULL,
  Date             TINYTEXT NULL,
  Class            SMALLINT UNSIGNED NOT NULL,
  TagBased         TINYTEXT NOT NULL
);

LOAD XML LOCAL INFILE 'Badges.xml' INTO TABLE BadgesXml
(Id, UserId, Name, Date, Class, TagBased);

CREATE TABLE REPLACEMEBadgeTypes (
  Id               SMALLINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  Description      TINYTEXT NOT NULL,
  TagBased         TINYINT(1) NOT NULL DEFAULT FALSE
);

INSERT INTO REPLACEMEBadgeTypes (Description, TagBased) SELECT DISTINCT Name, TagBased='True' FROM BadgesXml;

ANALYZE TABLE REPLACEMEBadgeTypes;

CREATE TABLE REPLACEMEBadges (
  Id               INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  BadgeTypeId      SMALLINT UNSIGNED NOT NULL,
  UserId           INT NOT NULL,
  CreationDate     DATETIME NULL
);

INSERT INTO REPLACEMEBadges (Id, BadgeTypeId, UserId, CreationDate)
SELECT b.Id, t.Id, b.UserId, STR_TO_DATE(b.Date, @DATETIME_ISO8601)
FROM BadgesXml AS b JOIN REPLACEMEBadgeTypes AS t ON b.Name=t.Description;

DROP TABLE BadgesXml;

ALTER TABLE REPLACEMEBadges
  ADD FOREIGN KEY (BadgeTypeId) REFERENCES REPLACEMEBadgeTypes(Id),
  ADD FOREIGN KEY (UserId) REFERENCES REPLACEMEUsers(Id);

ANALYZE TABLE REPLACEMEBadges;

/* ---------------------------------------------------------------------- */

CREATE TABLE REPLACEMEPosts (
  Id               INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  PostTypeId       TINYINT UNSIGNED NOT NULL,
  AcceptedAnswerId INT UNSIGNED NULL, -- only if PostTypeId = 1
  ParentId         INT UNSIGNED NULL, -- only if PostTypeId = 2
  CreationDate     DATETIME NOT NULL,
  Score            SMALLINT NOT NULL DEFAULT 0,
  ViewCount        INT UNSIGNED NOT NULL DEFAULT 0,
  Body             TEXT NOT NULL,
  OwnerUserId      INT NULL,
  LastEditorUserId INT NULL,
  LastEditDate     DATETIME NULL,
  LastActivityDate DATETIME NULL,
  Title            TINYTEXT NOT NULL,
  Tags             TINYTEXT NOT NULL,
  AnswerCount      SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  CommentCount     SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  FavoriteCount    SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  ClosedDate       DATETIME NULL
);

LOAD XML LOCAL INFILE 'Posts.xml' INTO TABLE REPLACEMEPosts
(Id, PostTypeId, AcceptedAnswerId, ParentId, @CreationDate, Score, ViewCount, Body, OwnerUserId, LastEditorUserId, @LastEditDate, @LastActivityDate, Title, Tags, AnswerCount, CommentCount, FavoriteCount, @ClosedDate)
SET CreationDate = STR_TO_DATE(@CreationDate, @DATETIME_ISO8601),
    LastEditDate = STR_TO_DATE(@LastEditDate, @DATETIME_ISO8601),
    LastActivityDate = STR_TO_DATE(@LastActivityDate, @DATETIME_ISO8601),
    ClosedDate = STR_TO_DATE(@ClosedDate, @DATETIME_ISO8601);

ALTER TABLE REPLACEMEPosts
  ADD FOREIGN KEY (PostTypeId) REFERENCES PostTypes(Id),
  ADD FOREIGN KEY (AcceptedAnswerId) REFERENCES REPLACEMEPosts(Id),
  ADD FOREIGN KEY (ParentId) REFERENCES REPLACEMEPosts(Id),
  ADD FOREIGN KEY (OwnerUserId) REFERENCES REPLACEMEUsers(Id),
  ADD FOREIGN KEY (LastEditorUserId) REFERENCES REPLACEMEUsers(Id);

ANALYZE TABLE REPLACEMEPosts;

CREATE OR REPLACE VIEW Questions AS SELECT * FROM REPLACEMEPosts WHERE PostTypeId = 1;
CREATE OR REPLACE VIEW Answers   AS SELECT * FROM REPLACEMEPosts WHERE PostTypeId = 2;

/* ---------------------------------------------------------------------- */

CREATE TABLE REPLACEMEComments (
  Id               INT UNSIGNED PRIMARY KEY,
  PostId           INT UNSIGNED NOT NULL,
  Score            INT NOT NULL,
  Text             TEXT NOT NULL,
  CreationDate     DATETIME NOT NULL,
  UserId           INT NOT NULL
);

LOAD XML LOCAL INFILE 'Comments.xml' INTO TABLE REPLACEMEComments
(Id, PostId, Score, Text, @CreationDate, UserId)
SET CreationDate = STR_TO_DATE(@CreationDate, @DATETIME_ISO8601);

DELETE c FROM REPLACEMEComments c LEFT JOIN REPLACEMEUsers u ON c.UserId=u.Id WHERE u.Id IS NULL;

ALTER TABLE REPLACEMEComments
  ADD FOREIGN KEY (PostId) REFERENCES REPLACEMEPosts(Id),
  ADD FOREIGN KEY (UserId) REFERENCES REPLACEMEUsers(Id);

ANALYZE TABLE REPLACEMEComments;

/* ---------------------------------------------------------------------- */

CREATE TABLE REPLACEMEPostHistory (
  Id               INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  PostHistoryTypeId TINYINT UNSIGNED NOT NULL,
  PostId           INT UNSIGNED NOT NULL,
  RevisionGUID     CHAR(36) CHARACTER SET ascii NOT NULL,
  CreationDate     DATETIME NOT NULL,
  UserId           INT NULL,
  Text             TEXT NULL
);

LOAD XML LOCAL INFILE 'PostHistory.xml' INTO TABLE REPLACEMEPostHistory
(Id, PostHistoryTypeId, PostId, RevisionGUID, @CreationDate, UserId, Text)
SET CreationDate = STR_TO_DATE(@CreationDate, @DATETIME_ISO8601);

DELETE h FROM REPLACEMEPostHistory h LEFT JOIN REPLACEMEUsers u ON h.PostHistoryTypeId=u.Id WHERE u.Id IS NULL;

ALTER TABLE REPLACEMEPostHistory
  /* ADD FOREIGN KEY (PostHistoryTypeId) REFERENCES PostHistoryTypes(Id), */
  ADD FOREIGN KEY (PostId) REFERENCES REPLACEMEPosts(Id),
  ADD FOREIGN KEY (UserId) REFERENCES REPLACEMEUsers(Id);

ANALYZE TABLE REPLACEMEPostHistory;

/* ---------------------------------------------------------------------- */

CREATE TABLE VotesXml (
  Id               INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  PostId           INT UNSIGNED NOT NULL,
  VoteTypeId       TINYINT UNSIGNED NOT NULL,
  UserId           TINYTEXT,
  CreationDate     TINYTEXT
);

LOAD XML LOCAL INFILE 'Votes.xml' INTO TABLE VotesXml
(Id, PostId, VoteTypeId, UserId, CreationDate);

CREATE TABLE REPLACEMEVotes (
  Id               INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  PostId           INT UNSIGNED NOT NULL,
  VoteTypeId       TINYINT UNSIGNED NOT NULL,
  UserId           INT NULL, -- only if VoteTypeId = 5
  CreationDate     DATETIME NOT NULL
);

INSERT INTO REPLACEMEVotes (Id, PostId, VoteTypeId, UserId, CreationDate)
SELECT v.Id, v.PostId, v.VoteTypeId, v.UserId, STR_TO_DATE(v.CreationDate, @DATETIME_ISO8601)
FROM VotesXml AS v;

DROP TABLE VotesXml;

DELETE v FROM REPLACEMEVotes AS v LEFT JOIN REPLACEMEPosts AS p ON v.PostId=p.Id WHERE p.Id IS NULL;

ALTER TABLE REPLACEMEVotes
  ADD FOREIGN KEY (PostId) REFERENCES REPLACEMEPosts(Id),
  ADD FOREIGN KEY (UserId) REFERENCES REPLACEMEUsers(Id),
  ADD FOREIGN KEY (VoteTypeId) REFERENCES VoteTypes(Id);

ANALYZE TABLE REPLACEMEVotes;

/* ---------------------------------------------------------------------- */

/*
CREATE TABLE Tags (
  Id               SMALLINT UNSIGNED PRIMARY KEY,
  Tag              VARCHAR(32) NOT NULL
);
ANALYZE TABLE Tags;
CREATE TABLE PostTags (
  PostId           INT UNSIGNED NOT NULL,
  TagId            SMALLINT UNSIGNED NOT NULL,
  PRIMARY KEY (PostId, TagId)
);
ALTER TABLE PostTags
  ADD FOREIGN KEY (PostId) REFERENCES Posts(Id),
  ADD FOREIGN KEY (TagId) REFERENCES Tags(Id);
ANALYZE TABLE PostTags;
*/

/* ---------------------------------------------------------------------- */

SELECT COALESCE(TABLE_NAME, 'TOTAL') AS TABLE_NAME,
  ROUND(SUM(DATA_LENGTH+INDEX_LENGTH)/1024/1024, 2) AS MB
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA='StackExchange'
GROUP BY TABLE_NAME WITH ROLLUP;
