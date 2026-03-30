-- 查询设备 39360002644 的基本信息
SELECT 
    d.device_id,
    d.device_name,
    d.device_type,
    d.phone,
    d.sim_number,
    d.status,
    d.battery,
    d.battery_level,
    d.register_date,
    d.last_update,
    d.longitude,
    d.latitude,
    d.address,
    d.remark
FROM lot_device d
WHERE d.device_id = '39360002644';

-- 查询设备绑定关系
SELECT 
    b.id,
    b.user_id,
    b.device_id,
    b.bind_time,
    b.unbind_time,
    b.status,
    b.create_time
FROM lot_device_bind b
WHERE b.device_id = '39360002644';

-- 查询最近24小时的位置轨迹数据
SELECT 
    t.id,
    t.device_id,
    t.longitude,
    t.latitude,
    t.altitude,
    t.speed,
    t.direction,
    t.report_time,
    t.address,
    t.status
FROM lot_track t
WHERE t.device_id = '39360002644'
  AND t.report_time >= DATE_SUB(NOW(), INTERVAL 24 HOUR)
ORDER BY t.report_time DESC
LIMIT 1000;

-- 查询电子围栏数据
SELECT 
    f.id,
    f.device_id,
    f.fence_name,
    f.fence_type,
    f.longitude,
    f.latitude,
    f.radius,
    f.points,
    f.status,
    f.create_time
FROM lot_fence f
WHERE f.device_id = '39360002644';

-- 查询最近24小时的消息记录
SELECT 
    m.id,
    m.user_id,
    m.device_id,
    m.message_type,
    m.message_content,
    m.is_read,
    m.read_time,
    m.create_time
FROM lot_message_record m
WHERE m.device_id = '39360002644'
  AND m.create_time >= DATE_SUB(NOW(), INTERVAL 24 HOUR)
ORDER BY m.create_time DESC
LIMIT 100;

-- 查询最近24小时的告警信息
SELECT 
    a.id,
    a.device_id,
    a.alarm_type,
    a.alarm_content,
    a.alarm_time,
    a.status,
    a.handle_time,
    a.handle_result,
    a.create_time
FROM alarm_message a
WHERE a.device_id = '39360002644'
  AND a.alarm_time >= DATE_SUB(NOW(), INTERVAL 24 HOUR)
ORDER BY a.alarm_time DESC
LIMIT 100;


