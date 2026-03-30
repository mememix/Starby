import { useState, useEffect } from 'react';
import { Table, Space, Button, Card, Tag, Modal, Form, Input, Select, Switch, message, Descriptions } from 'antd';
import { PlusOutlined, EditOutlined, DeleteOutlined, EyeOutlined } from '@ant-design/icons';
import api from '../utils/api';

interface Device {
  id: string;
  deviceSn: string;
  name: string;
  status: 'online' | 'offline';
  userId: string;
  createdAt: string;
  lastLocation?: {
    latitude: number;
    longitude: number;
    recordedAt: string;
  };
}

export default function Devices() {
  const [loading, setLoading] = useState(false);
  const [devices, setDevices] = useState<Device[]>([]);
  const [modalVisible, setModalVisible] = useState(false);
  const [detailVisible, setDetailVisible] = useState(false);
  const [editingDevice, setEditingDevice] = useState<Device | null>(null);
  const [selectedDevice, setSelectedDevice] = useState<Device | null>(null);
  const [form] = Form.useForm();

  const loadDevices = async () => {
    setLoading(true);
    try {
      // TODO: 从 API 获取设备列表
      // const response = await api.get('/devices');
      // setDevices(response.data.devices);
      
      // 模拟数据
      setDevices([
        { 
          id: '1', 
          deviceSn: 'SN-001', 
          name: '小明的手表', 
          status: 'online', 
          userId: 'user1', 
          createdAt: '2026-03-01',
          lastLocation: {
            latitude: 39.9042,
            longitude: 116.4074,
            recordedAt: '2026-03-13T10:00:00.000Z'
          }
        },
        { 
          id: '2', 
          deviceSn: 'SN-002', 
          name: '小红的手环', 
          status: 'online', 
          userId: 'user2', 
          createdAt: '2026-03-05',
          lastLocation: {
            latitude: 39.9142,
            longitude: 116.4174,
            recordedAt: '2026-03-13T10:30:00.000Z'
          }
        },
        { 
          id: '3', 
          deviceSn: 'SN-003', 
          name: '小华的定位器', 
          status: 'offline', 
          userId: 'user3', 
          createdAt: '2026-03-10'
        }
      ]);
    } catch (error) {
      message.error('加载设备失败');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadDevices();
  }, []);

  const handleDelete = (id: string) => {
    Modal.confirm({
      title: '确认删除',
      content: '确定要删除该设备吗？',
      onOk: async () => {
        try {
          // TODO: 调用删除 API
          message.success('删除成功');
          loadDevices();
        } catch (error) {
          message.error('删除失败');
        }
      }
    });
  };

  const handleSubmit = async (values: any) => {
    try {
      if (editingDevice) {
        // TODO: 调用更新 API
        message.success('更新成功');
      } else {
        // TODO: 调用创建 API
        message.success('创建成功');
      }
      setModalVisible(false);
      form.resetFields();
      loadDevices();
    } catch (error) {
      message.error('操作失败');
    }
  };

  const handleStatusChange = async (device: Device, checked: boolean) => {
    try {
      // TODO: 调用状态切换 API
      message.success(checked ? '设备已启用' : '设备已禁用');
      loadDevices();
    } catch (error) {
      message.error('操作失败');
    }
  };

  const columns = [
    { title: '设备编号', dataIndex: 'deviceSn', key: 'deviceSn' },
    { title: '设备名称', dataIndex: 'name', key: 'name' },
    { 
      title: '状态', 
      dataIndex: 'status', 
      key: 'status',
      render: (status: string) => (
        <Tag color={status === 'online' ? 'green' : 'red'}>
          {status === 'online' ? '在线' : '离线'}
        </Tag>
      )
    },
    { title: '最后位置', dataIndex: 'lastLocation', key: 'lastLocation',
      render: (loc: any) => loc ? `${loc.latitude.toFixed(4)}, ${loc.longitude.toFixed(4)}` : '-',
    },
    { title: '创建时间', dataIndex: 'createdAt', key: 'createdAt' },
    {
      title: '操作',
      key: 'action',
      render: (_: any, record: Device) => (
        <Space size="middle">
          <Button 
            type="link" 
            icon={<EyeOutlined />}
            onClick={() => {
              setSelectedDevice(record);
              setDetailVisible(true);
            }}
          >
            详情
          </Button>
          <Button 
            type="link" 
            icon={<EditOutlined />}
            onClick={() => {
              setEditingDevice(record);
              form.setFieldsValue(record);
              setModalVisible(true);
            }}
          >
            编辑
          </Button>
          <Switch 
            checked={record.status === 'online'}
            onChange={(checked) => handleStatusChange(record, checked)}
          />
          <Button 
            type="link" 
            danger 
            icon={<DeleteOutlined />}
            onClick={() => handleDelete(record.id)}
          >
            删除
          </Button>
        </Space>
      )
    }
  ];

  return (
    <>
      <Card 
        title="设备管理"
        extra={
          <Button 
            type="primary" 
            icon={<PlusOutlined />}
            onClick={() => {
              setEditingDevice(null);
              form.resetFields();
              setModalVisible(true);
            }}
          >
            添加设备
          </Button>
        }
      >
        <Table 
          columns={columns} 
          dataSource={devices}
          loading={loading}
          rowKey="id"
        />
      </Card>

      <Modal
        title={editingDevice ? '编辑设备' : '添加设备'}
        open={modalVisible}
        onCancel={() => setModalVisible(false)}
        footer={null}
        width={600}
      >
        <Form
          form={form}
          layout="vertical"
          onFinish={handleSubmit}
        >
          <Form.Item
            name="deviceSn"
            label="设备序列号"
            rules={[{ required: true, message: '请输入设备序列号' }]}
          >
            <Input placeholder="请输入设备序列号" disabled={!!editingDevice} />
          </Form.Item>
          <Form.Item
            name="name"
            label="设备名称"
            rules={[{ required: true, message: '请输入设备名称' }]}
          >
            <Input placeholder="请输入设备名称" />
          </Form.Item>
          <Form.Item
            name="status"
            label="状态"
            initialValue="offline"
          >
            <Select>
              <Select.Option value="online">在线</Select.Option>
              <Select.Option value="offline">离线</Select.Option>
            </Select>
          </Form.Item>
          <Form.Item>
            <Space>
              <Button type="primary" htmlType="submit">
                提交
              </Button>
              <Button onClick={() => setModalVisible(false)}>
                取消
              </Button>
            </Space>
          </Form.Item>
        </Form>
      </Modal>

      <Modal
        title="设备详情"
        open={detailVisible}
        onCancel={() => setDetailVisible(false)}
        footer={[
          <Button key="close" onClick={() => setDetailVisible(false)}>
            关闭
          </Button>
        ]}
        width={600}
      >
        {selectedDevice && (
          <Descriptions column={1} bordered>
            <Descriptions.Item label="设备编号">
              {selectedDevice.deviceSn}
            </Descriptions.Item>
            <Descriptions.Item label="设备名称">
              {selectedDevice.name}
            </Descriptions.Item>
            <Descriptions.Item label="状态">
              <Tag color={selectedDevice.status === 'online' ? 'green' : 'red'}>
                {selectedDevice.status === 'online' ? '在线' : '离线'}
              </Tag>
            </Descriptions.Item>
            <Descriptions.Item label="创建时间">
              {selectedDevice.createdAt}
            </Descriptions.Item>
            {selectedDevice.lastLocation && (
              <>
                <Descriptions.Item label="最后位置">
                  {selectedDevice.lastLocation.latitude.toFixed(4)}, {selectedDevice.lastLocation.longitude.toFixed(4)}
                </Descriptions.Item>
                <Descriptions.Item label="定位时间">
                  {new Date(selectedDevice.lastLocation.recordedAt).toLocaleString('zh-CN')}
                </Descriptions.Item>
              </>
            )}
          </Descriptions>
        )}
      </Modal>
    </>
  );
}
