-- 星护伙伴 - MySQL 数据库表结构
-- 适配 CloudBase MySQL 数据库

-- 用户表
CREATE TABLE IF NOT EXISTS users (
  id VARCHAR(36) PRIMARY KEY,
  phone VARCHAR(20) NOT NULL UNIQUE,
  passwordHash VARCHAR(255) NOT NULL,
  nickname VARCHAR(100),
  avatar VARCHAR(500),
  gender VARCHAR(10),
  region VARCHAR(100),
  bio TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  last_login_at DATETIME,
  INDEX idx_phone (phone)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 设备表
CREATE TABLE IF NOT EXISTS devices (
  id VARCHAR(36) PRIMARY KEY,
  user_id VARCHAR(36),
  device_sn VARCHAR(50) UNIQUE,
  phone_number VARCHAR(20) UNIQUE,
  name VARCHAR(100),
  device_type VARCHAR(20) DEFAULT 'mobile',
  status VARCHAR(20) DEFAULT 'offline',
  is_online BOOLEAN DEFAULT FALSE,
  last_online DATETIME,
  auth_code VARCHAR(50),
  manufacturer_id VARCHAR(50),
  terminal_model VARCHAR(50),
  terminal_id VARCHAR(50),
  license_plate VARCHAR(20),
  last_latitude DECIMAL(10, 6),
  last_longitude DECIMAL(10, 6),
  last_location_time DATETIME,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_user_id (user_id),
  INDEX idx_device_sn (device_sn),
  INDEX idx_phone_number (phone_number)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 位置表
CREATE TABLE IF NOT EXISTS locations (
  id VARCHAR(36) PRIMARY KEY,
  device_id VARCHAR(36) NOT NULL,
  latitude DECIMAL(10, 6) NOT NULL,
  longitude DECIMAL(10, 6) NOT NULL,
  altitude INT,
  speed DECIMAL(6, 2),
  direction INT,
  accuracy DECIMAL(6, 2),
  source VARCHAR(20) DEFAULT 'mobile',
  timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
  alarm_emergency BOOLEAN,
  alarm_overspeed BOOLEAN,
  alarm_fatigue BOOLEAN,
  alarm_power_low BOOLEAN,
  alarm_power_lost BOOLEAN,
  status_acc_on BOOLEAN,
  status_positioned BOOLEAN,
  status_door_locked BOOLEAN,
  recorded_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE CASCADE,
  INDEX idx_device_id (device_id),
  INDEX idx_timestamp (timestamp),
  INDEX idx_device_timestamp (device_id, timestamp)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 电子围栏表
CREATE TABLE IF NOT EXISTS fences (
  id VARCHAR(36) PRIMARY KEY,
  device_id VARCHAR(36) NOT NULL,
  name VARCHAR(100),
  latitude DECIMAL(10, 6) NOT NULL,
  longitude DECIMAL(10, 6) NOT NULL,
  radius INT NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE CASCADE,
  INDEX idx_device_id (device_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 消息表
CREATE TABLE IF NOT EXISTS messages (
  id VARCHAR(36) PRIMARY KEY,
  user_id VARCHAR(36) NOT NULL,
  device_id VARCHAR(36),
  type VARCHAR(20) NOT NULL,
  title VARCHAR(200) NOT NULL,
  content TEXT NOT NULL,
  is_read BOOLEAN DEFAULT FALSE,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  read_at DATETIME,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_user_id (user_id),
  INDEX idx_is_read (is_read),
  INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- SOS紧急联系人表
CREATE TABLE IF NOT EXISTS sos_contacts (
  id VARCHAR(36) PRIMARY KEY,
  user_id VARCHAR(36) NOT NULL,
  device_id VARCHAR(36),
  name VARCHAR(50) NOT NULL,
  phone VARCHAR(20) NOT NULL,
  relation VARCHAR(20),
  is_primary BOOLEAN DEFAULT FALSE,
  order_num INT DEFAULT 0,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_user_id (user_id),
  INDEX idx_device_id (device_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
