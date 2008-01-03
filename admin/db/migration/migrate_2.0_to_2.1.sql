-- MySQL dump 10.10
--
-- Host: localhost    Database: test
-- ------------------------------------------------------
-- Server version	5.0.27

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

-- #####################################################################
-- The following are additional tables for the extended tracking system.
-- #####################################################################

--
-- Table structure for table `array_designs_organisms`
--

DROP TABLE IF EXISTS `array_designs_organisms`;
CREATE TABLE `array_designs_organisms` (
  `id` int(11) NOT NULL auto_increment,
  `organism_id` int(11) NOT NULL,
  `array_design_id` int(11) NOT NULL,
  PRIMARY KEY  (`id`),
  KEY `organism_id` (`organism_id`),
  KEY `array_design_id` (`array_design_id`),
  CONSTRAINT `array_designs_organisms_ibfk_1` FOREIGN KEY (`organism_id`) REFERENCES `organisms` (`id`) ON DELETE CASCADE,
  CONSTRAINT `array_designs_organisms_ibfk_2` FOREIGN KEY (`array_design_id`) REFERENCES `array_designs` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `quantitation_types`
--

DROP TABLE IF EXISTS `quantitation_types`;
CREATE TABLE `quantitation_types` (
  `id` int(11) NOT NULL auto_increment,
  `name` varchar(128) NOT NULL,
  `is_deleted` int(11) NOT NULL,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `experiments_quantitation_types`
--

DROP TABLE IF EXISTS `experiments_quantitation_types`;
CREATE TABLE `experiments_quantitation_types` (
  `id` int(11) NOT NULL auto_increment,
  `quantitation_type_id` int(11) NOT NULL,
  `experiment_id` int(11) NOT NULL,
  PRIMARY KEY  (`id`),
  KEY `quantitation_type_id` (`quantitation_type_id`),
  KEY `experiment_id` (`experiment_id`),
  CONSTRAINT `experiments_quantitation_types_ibfk_1` FOREIGN KEY (`quantitation_type_id`) REFERENCES `quantitation_types` (`id`) ON DELETE CASCADE,
  CONSTRAINT `experiments_quantitation_types_ibfk_2` FOREIGN KEY (`experiment_id`) REFERENCES `experiments` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `array_designs_experiments`
--

DROP TABLE IF EXISTS `array_designs_experiments`;
CREATE TABLE `array_designs_experiments` (
  `id` int(11) NOT NULL auto_increment,
  `array_design_id` int(11) NOT NULL,
  `experiment_id` int(11) NOT NULL,
  PRIMARY KEY  (`id`),
  KEY `array_design_id` (`array_design_id`),
  KEY `experiment_id` (`experiment_id`),
  CONSTRAINT `array_designs_experiments_ibfk_1` FOREIGN KEY (`array_design_id`) REFERENCES `array_designs` (`id`) ON DELETE CASCADE,
  CONSTRAINT `array_designs_experiments_ibfk_2` FOREIGN KEY (`experiment_id`) REFERENCES `experiments` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `factors`
--

DROP TABLE IF EXISTS `factors`;
CREATE TABLE `factors` (
  `id` int(11) NOT NULL auto_increment,
  `name` varchar(128) NOT NULL,
  `is_deleted` int(11) NOT NULL,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `experiments_factors`
--

DROP TABLE IF EXISTS `experiments_factors`;
CREATE TABLE `experiments_factors` (
  `id` int(11) NOT NULL auto_increment,
  `experiment_id` int(11) NOT NULL,
  `factor_id` int(11) NOT NULL,
  PRIMARY KEY  (`id`),
  KEY `experiment_id` (`experiment_id`),
  KEY `factor_id` (`factor_id`),
  CONSTRAINT `experiments_factors_ibfk_1` FOREIGN KEY (`factor_id`) REFERENCES `factors` (`id`) ON DELETE CASCADE,
  CONSTRAINT `experiments_factors_ibfk_2` FOREIGN KEY (`experiment_id`) REFERENCES `experiments` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `events`
--

DROP TABLE IF EXISTS `events`;
CREATE TABLE `events` (
  `id` int(11) NOT NULL auto_increment,
  `array_design_id` int(11) default NULL,
  `experiment_id` int(11) default NULL,
  `event_type` varchar(50) NOT NULL,
  `was_successful` int(11) default NULL,
  `source_db` varchar(30) default NULL,
  `target_db` varchar(30) default NULL,
  `start_time` datetime default NULL,        -- REDUNDANT
  `end_time` datetime default NULL,          -- REDUNDANT
  `machine` varchar(30) default NULL,
  `operator` varchar(30) default NULL,
  `log_file` varchar(255) default NULL,
  `jobregister_dbid` int(13) default NULL,
  `comment` text,
  `is_deleted` int(11) NOT NULL,
  PRIMARY KEY  (`id`),
  KEY `array_design_id` (`array_design_id`),
  KEY `experiment_id` (`experiment_id`),
  CONSTRAINT `events_ibfk_1` FOREIGN KEY (`array_design_id`) REFERENCES `array_designs` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `events_ibfk_2` FOREIGN KEY (`experiment_id`) REFERENCES `experiments` (`id`) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- #######################################
-- Additional columns for existing tables.
-- #######################################

ALTER TABLE experiments ADD COLUMN (
  `num_submissions` int(11) default NULL,
  `submitter_description` text,                    -- REDUNDANT
  `curated_name` varchar(255) default NULL,        -- REDUNDANT
  `num_samples` int(11) default NULL,              -- REDUNDANT
  `num_hybridizations` int(11) default NULL,       -- REDUNDANT
  `has_raw_data` int(11) default NULL,             -- REDUNDANT
  `has_processed_data` int(11) default NULL,       -- REDUNDANT
  `release_date` datetime default NULL,            -- REDUNDANT
  `is_released` int(11) default NULL,              -- REDUNDANT
  `ae_miame_score` int(11) default NULL,           -- REDUNDANT
  `ae_data_warehouse_score` int(11) default NULL   -- REDUNDANT
);

ALTER TABLE array_designs ADD COLUMN (
  `annotation_source` varchar(50) default NULL,    -- REDUNDANT?
  `annotation_version` varchar(50) default NULL,   -- REDUNDANT?
  `biomart_table_name` varchar(50) default NULL,   -- REDUNDANT?
  `release_date` datetime default NULL,            -- REDUNDANT
  `is_released` int(11) default NULL               -- REDUNDANT
);

-- ###############################################################
-- We need to relax the requirement that all organisms have taxon;
-- otherwise auto-inserting new organisms gets ugly.
-- ###############################################################
ALTER TABLE organisms MODIFY COLUMN taxon_id int(11) DEFAULT NULL;
ALTER TABLE array_designs MODIFY COLUMN accession varchar(255) DEFAULT NULL;
ALTER TABLE experiments MODIFY COLUMN accession varchar(255) DEFAULT NULL;

-- Fix our legacy submissions.
UPDATE experiments SET num_submissions=1 where in_curation=1;

/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;
