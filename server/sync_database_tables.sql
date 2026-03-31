-- ====================================================================
-- 数据库表结构同步脚本 - 方案1: 完全同步开发和生产环境
-- ====================================================================
-- 执行时间: 2026-03-31
-- 说明: 同步开发环境和生产环境的表结构,使其完全一致
-- ====================================================================

-- ====================================================================
-- 步骤1: 在生产数据库 ry-cloud 中创建 lot_user_login_device 表
-- ====================================================================
USE `ry-cloud`;

CREATE TABLE IF NOT EXISTS `lot_user_login_device` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `user_id` bigint NOT NULL,
  `device_id` varchar(128) NOT NULL,
  `device_name` varchar(100) DEFAULT '',
  `device_type` varchar(50) DEFAULT '',
  `ip_address` varchar(128) DEFAULT '',
  `location` varchar(255) DEFAULT '',
  `user_agent` varchar(500) DEFAULT '',
  `is_current` tinyint(1) DEFAULT 0,
  `last_login_time` datetime DEFAULT NULL,
  `create_time` datetime DEFAULT CURRENT_TIMESTAMP,
  `update_time` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `del_flag` tinyint(1) DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_device_id` (`device_id`),
  KEY `idx_user_id` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='登录设备表';

SELECT '生产数据库 ry-cloud: lot_user_login_device 表创建完成' AS result;

-- ====================================================================
-- 步骤2: 在开发数据库 starby-dev 中创建生产环境特有的表
-- ====================================================================
USE `starby-dev`;

-- 创建 lot_checkin_stats 表
CREATE TABLE IF NOT EXISTS `lot_checkin_stats` (
  `stats_id` bigint NOT NULL AUTO_INCREMENT,
  `user_id` bigint NOT NULL,
  `stats_year` int NOT NULL,
  `stats_month` int NOT NULL,
  `total_days` int DEFAULT 0,
  `continuous_days` int DEFAULT 0,
  `last_checkin_date` date DEFAULT NULL,
  `create_time` datetime DEFAULT CURRENT_TIMESTAMP,
  `update_time` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`stats_id`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_stats_year` (`stats_year`),
  KEY `idx_stats_month` (`stats_month`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='打卡统计表';

SELECT '开发数据库 starby-dev: lot_checkin_stats 表创建完成' AS result;

-- 创建 lot_points_record 表
CREATE TABLE IF NOT EXISTS `lot_points_record` (
  `record_id` bigint NOT NULL AUTO_INCREMENT,
  `user_id` bigint NOT NULL,
  `points` int NOT NULL,
  `record_type` varchar(50) DEFAULT 'CHECKIN',
  `description` varchar(200) DEFAULT NULL,
  `related_id` bigint DEFAULT NULL,
  `create_time` datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`record_id`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_record_type` (`record_type`),
  KEY `idx_create_time` (`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='积分记录表';

SELECT '开发数据库 starby-dev: lot_points_record 表创建完成' AS result;

-- ====================================================================
-- 步骤3: 验证表结构
-- ====================================================================
USE `ry-cloud`;
SELECT '生产数据库 ry-cloud 中的表:' AS result;
SHOW TABLES LIKE 'lot_%';

USE `starby-dev`;
SELECT '开发数据库 starby-dev 中的表:' AS result;
SHOW TABLES LIKE 'lot_%';

-- ====================================================================
-- 执行完成
-- ====================================================================
SELECT '========================================' AS result;
SELECT '数据库表结构同步完成!' AS result;
SELECT '生产数据库 ry-cloud 新增: lot_user_login_device' AS result;
SELECT '开发数据库 starby-dev 新增: lot_checkin_stats, lot_points_record' AS result;
SELECT '========================================' AS result;
