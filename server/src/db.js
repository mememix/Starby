// 简单的数据库连接模块，使用原始 SQL
import mysql from 'mysql2/promise';

let pool;

export const createDbPool = () => {
  if (!pool) {
    pool = mysql.createPool({
      host: '116.204.117.57',
      port: 3307,
      user: 'root',
      password: 'StrongPass!',
      database: 'starby-dev',
      waitForConnections: true,
      connectionLimit: 10,
      queueLimit: 0
    });
  }
  return pool;
};

export const db = createDbPool();

export const query = async (sql, params = []) => {
  try {
    const [rows] = await db.execute(sql, params);
    return rows;
  } catch (error) {
    console.error('数据库查询错误:', error.message);
    throw error;
  }
};
