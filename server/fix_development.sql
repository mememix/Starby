-- ====================================================================
-- 开发数据库 starby-dev 修复脚本
-- ====================================================================
USE `starby-dev`;

-- 优化 lot_checkin_stats 表的索引
-- 1. 删除单列索引
ALTER TABLE `lot_checkin_stats` DROP INDEX `idx_stats_year`;
ALTER TABLE `lot_checkin_stats` DROP INDEX `idx_stats_month`;

-- 2. 添加组合索引
ALTER TABLE `lot_checkin_stats` ADD INDEX `idx_year_month` (`stats_year`, `stats_month`);

-- 3. 添加唯一索引
ALTER TABLE `lot_checkin_stats` ADD UNIQUE INDEX `uk_user_year_month` (`user_id`, `stats_year`, `stats_month`);

SELECT '✅ lot_checkin_stats 表索引优化完成' AS status;

-- 验证
SHOW INDEX FROM `lot_checkin_stats`;
