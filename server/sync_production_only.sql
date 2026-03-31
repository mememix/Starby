-- ====================================================================
-- 生产数据库单独同步脚本
-- ====================================================================
-- 说明: 在生产数据库 ry-cloud 中创建 lot_user_login_device 表
-- ====================================================================

USE `ry-cloud`;

-- 创建 lot_user_login_device 表
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

-- 验证表是否创建成功
SELECT '========================================' AS status;
SELECT 'lot_user_login_device 表创建完成!' AS message;
SELECT '========================================' AS status;

SHOW TABLES LIKE 'lot_user_login_device';
DESC `lot_user_login_device`;
