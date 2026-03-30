import { useState, useEffect } from 'react';
import { Row, Col, Card, Statistic, Table, Space, Button } from 'antd';
import { UserOutlined, DeviceOutlined, ClockCircleOutlined, CheckCircleOutlined } from '@ant-design/icons';

export default function Dashboard() {
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // TODO: 从 API 获取统计数据
    setLoading(false);
  }, []);

  const stats = [
    { title: '总用户数', value: '1,234', icon: <UserOutlined />, color: '#3f8600' },
    { title: '在线设备', value: '567', icon: <DeviceOutlined />, color: '#1890ff' },
    { title: '今日活跃', value: '234', icon: <ClockCircleOutlined />, color: '#722ed1' },
    { title: '正常设备', value: '560', icon: <CheckCircleOutlined />, color: '#52c41a' }
  ];

  const recentDevices = [
    { key: '1', name: '小明的手表', user: '张三', status: 'online', lastActive: '5分钟前' },
    { key: '2', name: '小红的手环', user: '李四', status: 'online', lastActive: '10分钟前' },
    { key: '3', name: '小华的定位器', user: '王五', status: 'offline', lastActive: '1小时前' }
  ];

  const columns = [
    { title: '设备名称', dataIndex: 'name', key: 'name' },
    { title: '所属用户', dataIndex: 'user', key: 'user' },
    { 
      title: '状态', 
      dataIndex: 'status', 
      key: 'status',
      render: (status: string) => (
        <span style={{ color: status === 'online' ? '#52c41a' : '#ff4d4f' }}>
          {status === 'online' ? '在线' : '离线'}
        </span>
      )
    },
    { title: '最后活跃', dataIndex: 'lastActive', key: 'lastActive' }
  ];

  return (
    <div>
      <Row gutter={[16, 16]} style={{ marginBottom: 24 }}>
        {stats.map((stat, index) => (
          <Col xs={24} sm={12} md={6} key={index}>
            <Card>
              <Statistic
                title={stat.title}
                value={stat.value}
                prefix={stat.icon}
                valueStyle={{ color: stat.color }}
                loading={loading}
              />
            </Card>
          </Col>
        ))}
      </Row>

      <Card 
        title="最近活跃设备" 
        extra={<Button type="primary">查看全部</Button>}
      >
        <Table 
          columns={columns} 
          dataSource={recentDevices}
          pagination={false}
          loading={loading}
        />
      </Card>
    </div>
  );
}
