-- ====================================================================
-- 生产数据库 ry-cloud 修复脚本
-- ====================================================================
USE `ry-cloud`;

-- 1. 创建 lot_user_login_device 表
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

SELECT '✅ lot_user_login_device 表创建完成' AS status;

-- 2. 在 lot_checkin 表中添加 points 字段
ALTER TABLE `lot_checkin`
ADD COLUMN `points` int DEFAULT 0 COMMENT '获得积分' AFTER `update_by`;

SELECT '✅ lot_checkin 表添加 points 字段完成' AS status;

-- 验证
SELECT '========================================' AS status;
SELECT '生产数据库修复完成!' AS status;
SHOW TABLES LIKE 'lot_user_login_device';
DESC `lot_user_login_device`;
