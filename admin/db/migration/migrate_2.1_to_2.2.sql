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

-- #######################################################################
-- The following are additional tables for the loaded data hashing system.
-- #######################################################################

--
-- Table structure for table `data_formats`
--

DROP TABLE IF EXISTS `data_formats`;
CREATE TABLE `data_formats` (
  `id` int(11) NOT NULL auto_increment,
  `name` varchar(50) COLLATE latin1_general_cs UNIQUE NOT NULL,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `loaded_data`
--

DROP TABLE IF EXISTS `loaded_data`;
CREATE TABLE `loaded_data` (
  `id` int(11) NOT NULL auto_increment,
  `identifier` varchar(255) COLLATE latin1_general_cs UNIQUE NOT NULL,
  `md5_hash` char(35) NOT NULL,
  `data_format_id` int(11) NOT NULL,
  PRIMARY KEY  (`id`),
  KEY `data_format_id` (`data_format_id`),
  CONSTRAINT `data_format_loaded_data_ibfk_1` FOREIGN KEY (`data_format_id`) REFERENCES `data_formats` (`id`) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `quality_metrics`
--

DROP TABLE IF EXISTS `quality_metrics`;
CREATE TABLE `quality_metrics` (
  `id` int(11) NOT NULL auto_increment,
  `type` varchar(50) UNIQUE NOT NULL,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `experiments_loaded_data`
--

DROP TABLE IF EXISTS `experiments_loaded_data`;
CREATE TABLE `experiments_loaded_data` (
  `experiment_id` int(11) NOT NULL,
  `loaded_data_id` int(11) NOT NULL,
  KEY `experiment_id` (`experiment_id`),
  KEY `loaded_data_id` (`loaded_data_id`),
  CONSTRAINT `loaded_data_experiment_ibfk_1` FOREIGN KEY (`experiment_id`) REFERENCES `experiments` (`id`) ON DELETE CASCADE,
  CONSTRAINT `loaded_data_loaded_data_ibfk_1` FOREIGN KEY (`loaded_data_id`) REFERENCES `loaded_data` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `loaded_data_quality_metrics`
--

DROP TABLE IF EXISTS `loaded_data_quality_metrics`;
CREATE TABLE `loaded_data_quality_metrics` (
  `id` int(11) NOT NULL auto_increment,
  `value` decimal(12,5),
  `quality_metric_id` int(11) NOT NULL,
  `loaded_data_id` int(11) NOT NULL,
  PRIMARY KEY  (`id`),
  KEY `quality_metric_id` (`quality_metric_id`),
  KEY `loaded_data_id` (`loaded_data_id`),
  CONSTRAINT `quality_metric_quality_metric_ibfk_1` FOREIGN KEY (`quality_metric_id`) REFERENCES `quality_metrics` (`id`) ON DELETE CASCADE,
  CONSTRAINT `quality_metric_loaded_data_ibfk_1` FOREIGN KEY (`loaded_data_id`) REFERENCES `loaded_data` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Fix the matching of QT so that it's case sensitive
--
ALTER TABLE `quantitation_types` MODIFY COLUMN `name` varchar(128) COLLATE latin1_general_cs NOT NULL;

/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;
