-- 同步设备表的绑定状态

-- 1. 更新有有效绑定的设备状态为"已绑定"
UPDATE lot_device d
INNER JOIN lot_user_device_bind b ON d.device_id = b.device_id
INNER JOIN sys_user u ON b.user_id = u.user_id
SET d.user_phone = u.phonenumber,
    d.user_name = b.device_name,
    d.bind_status = 1,
    d.bind_date = b.bind_time,
    d.update_time = NOW()
WHERE b.bind_status = 1
  AND b.bind_id = (
    SELECT MIN(bind_id)
    FROM lot_user_device_bind b2
    WHERE b2.device_id = d.device_id AND b2.bind_status = 1
  );

-- 2. 清理没有有效绑定的设备状态为"未绑定"
UPDATE lot_device
SET user_phone = NULL,
    user_name = NULL,
    bind_status = 0,
    bind_date = NULL,
    update_time = NOW()
WHERE del_flag = '0'
  AND device_id NOT IN (
    SELECT DISTINCT device_id
    FROM lot_user_device_bind
    WHERE bind_status = 1
  );

-- 3. 验证设备39360002644（白2）的清理结果
SELECT '设备39360002644的验证结果:' AS info,
       device_id, device_code, device_name, user_phone, bind_status, create_time, update_time
FROM lot_device
WHERE device_code = '39360002644' AND del_flag = '0';

-- 4. 验证182账户的设备列表
SELECT '182账户（user_id=100）的绑定设备:' AS info,
       b.bind_id, b.user_id, b.device_id, b.device_no, b.device_name, b.bind_status, b.bind_time,
       d.device_code, d.device_name AS original_device_name, d.user_phone AS device_user_phone, d.bind_status AS device_bind_status
FROM lot_user_device_bind b
LEFT JOIN lot_device d ON b.device_id = d.device_id
WHERE b.user_id = 100 AND b.bind_status = 1
ORDER BY b.bind_time DESC;

-- 5. 对比两种查询方式
SELECT '对比两种查询方式:' AS info,
       (SELECT COUNT(*) FROM lot_user_device_bind WHERE user_id = 100 AND bind_status = 1) AS 绑定表查询,
       (SELECT COUNT(*) FROM lot_device WHERE user_phone = '18201162729' AND del_flag = '0') AS 设备表查询;

-- 6. 显示可绑定的设备（前10个）
SELECT '可绑定的设备（前10个）:' AS info,
       device_id, device_code, device_name
FROM lot_device
WHERE del_flag = '0' AND device_id NOT IN (
  SELECT DISTINCT device_id FROM lot_user_device_bind WHERE bind_status = 1
)
ORDER BY device_code ASC
LIMIT 10;
