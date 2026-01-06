/*
SQLyog Ultimate v8.32 
MySQL - 5.1.21-beta-community : Database - entropic
*********************************************************************
*/

/*!40101 SET NAMES utf8 */;

/*!40101 SET SQL_MODE=''*/;

/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;
CREATE DATABASE /*!32312 IF NOT EXISTS*/`entropic` /*!40100 DEFAULT CHARACTER SET latin1 */;

USE `entropic`;

/*Table structure for table `query_string` */

DROP TABLE IF EXISTS `query_string`;

CREATE TABLE `query_string` (
  `QString` longtext,
  `Conteggio` int(11) DEFAULT '1'
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

/*Table structure for table `conteggia_querystring` */

DROP TABLE IF EXISTS `conteggia_querystring`;

/*!50001 DROP VIEW IF EXISTS `conteggia_querystring` */;
/*!50001 DROP TABLE IF EXISTS `conteggia_querystring` */;

/*!50001 CREATE TABLE  `conteggia_querystring`(
 `QString` longtext ,
 `Conteggio` decimal(32,0) 
)*/;

/*View structure for view conteggia_querystring */

/*!50001 DROP TABLE IF EXISTS `conteggia_querystring` */;
/*!50001 DROP VIEW IF EXISTS `conteggia_querystring` */;

/*!50001 CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `conteggia_querystring` AS (select `query_string`.`QString` AS `QString`,sum(`query_string`.`Conteggio`) AS `Conteggio` from `query_string` group by `query_string`.`QString`) */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;
