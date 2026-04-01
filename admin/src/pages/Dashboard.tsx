import { useState, useEffect } from 'react';
import { Row, Col, Card, Statistic, Table, Space, Button, Input, message } from 'antd';
import { UserOutlined, MobileOutlined, ClockCircleOutlined, CheckCircleOutlined, SearchOutlined } from '@ant-design/icons';
import api from '../utils/api';

interface StatCard {
  title: string;
  value: string | number;
  icon: React.ReactNode;
  color: string;
}

interface Device {
  key: string;
  name: string;
  user: string;
  online: boolean;
  lastActive: string;
}

export default function Dashboard() {
  const [loading, setLoading] = useState(true);
  const [stats, setStats] = useState<StatCard[]>([
    { title: '总用户数', value: '0', icon: <UserOutlined />, color: '#3f8600' },
    { title: '在线设备', value: '0', icon: <MobileOutlined />, color: '#1890ff' },
    { title: '今日活跃', value: '0', icon: <ClockCircleOutlined />, color: '#722ed1' },
    { title: '正常设备', value: '0', icon: <CheckCircleOutlined />, color: '#52c41a' }
  ]);
  const [recentDevices, setRecentDevices] = useState<Device[]>([]);
  const [searchText, setSearchText] = useState('');
  const [filteredDevices, setFilteredDevices] = useState<Device[]>([]);

  useEffect(() => {
    fetchDashboardData();
  }, []);

  const fetchDashboardData = async () => {
    try {
      setLoading(true);

      // 获取统计数据 - 使用正确的管理员统计接口
      const statsResponse = await api.get('/devices/stats');
      if (statsResponse.success) {
        const { totalUsers, onlineDevices, todayActive, normalDevices } = statsResponse.data;
        setStats([
          { title: '总用户数', value: totalUsers || 0, icon: <UserOutlined />, color: '#3f8600' },
          { title: '在线设备', value: onlineDevices || 0, icon: <MobileOutlined />, color: '#1890ff' },
          { title: '今日活跃', value: todayActive || 0, icon: <ClockCircleOutlined />, color: '#722ed1' },
          { title: '正常设备', value: normalDevices || 0, icon: <CheckCircleOutlined />, color: '#52c41a' }
        ]);
      }

      // 获取设备列表 - 使用管理员设备列表接口
      const devicesResponse = await api.get('/devices/all?limit=10');
      if (devicesResponse.success && devicesResponse.data) {
        const devices = devicesResponse.data.devices || [];
        const formattedDevices: Device[] = devices.map((device: any) => ({
          key: device.id,
          name: device.name,
          user: device.userName,
          online: device.online || false,
          lastActive: device.lastOnline || '未知'
        }));
        setRecentDevices(formattedDevices);
        setFilteredDevices(formattedDevices);
      }
    } catch (error) {
      console.error('获取仪表盘数据失败:', error);
      message.error('获取数据失败');
    } finally {
      setLoading(false);
    }
  };

  const columns = [
    { title: '设备名称', dataIndex: 'name', key: 'name' },
    { title: '所属用户', dataIndex: 'user', key: 'user' },
    {
      title: '状态',
      dataIndex: 'online',
      key: 'online',
      render: (online: boolean) => (
        <span style={{ color: online ? '#52c41a' : '#ff4d4f' }}>
          {online ? '在线' : '离线'}
        </span>
      )
    },
    { title: '最后活跃', dataIndex: 'lastActive', key: 'lastActive' }
  ];

  return (
    <div style={{ width: '100%' }}>
      <Row gutter={[16, 16]} style={{ marginBottom: 24, width: '100%' }}>
        {stats.map((stat, index) => (
          <Col xs={24} sm={12} lg={6} key={index}>
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
        extra={
          <Space size="middle">
            <Input.Search
              placeholder="搜索设备名称/所属用户"
              value={searchText}
              onChange={(e) => setSearchText(e.target.value)}
              allowClear
              style={{ width: 250 }}
              prefix={<SearchOutlined />}
            />
            <Button type="primary" onClick={() => window.location.href = '/starby-admin/devices'}>
              查看全部
            </Button>
          </Space>
        }
      >
        <Table
          columns={columns}
          dataSource={filteredDevices}
          pagination={false}
          loading={loading}
          scroll={{ x: true }}
        />
      </Card>
    </div>
  );
}
