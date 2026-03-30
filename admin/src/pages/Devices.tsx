import { useState, useEffect } from 'react';
import { Table, Space, Button, Card, Tag, Modal, Form, Input, Select, Switch, message, Descriptions, Avatar } from 'antd';
import { PlusOutlined, EditOutlined, DeleteOutlined, EyeOutlined, SearchOutlined } from '@ant-design/icons';
import api from '../utils/api';

interface Device {
  id: string;
  deviceCode: string;
  name: string;
  online: boolean;
  userName: string;
  userPhone: string;
  lastOnline: string;
}

export default function Devices() {
  const [loading, setLoading] = useState(false);
  const [devices, setDevices] = useState<Device[]>([]);
  const [searchText, setSearchText] = useState('');
  const [filteredDevices, setFilteredDevices] = useState<Device[]>([]);
  const [modalVisible, setModalVisible] = useState(false);
  const [detailVisible, setDetailVisible] = useState(false);
  const [editingDevice, setEditingDevice] = useState<Device | null>(null);
  const [selectedDevice, setSelectedDevice] = useState<Device | null>(null);
  const [form] = Form.useForm();

  const loadDevices = async () => {
    setLoading(true);
    try {
      const response = await api.get('/devices/all?limit=100');
      if (response.success) {
        setDevices(response.data.devices || []);
      }
    } catch (error) {
      console.error('加载设备失败:', error);
      message.error('加载设备失败');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadDevices();
  }, []);

  // 根据搜索文本过滤设备
  useEffect(() => {
    if (searchText.trim() === '') {
      setFilteredDevices(devices);
    } else {
      const searchLower = searchText.toLowerCase();
      const filtered = devices.filter(device =>
        (device.name && device.name.toLowerCase().includes(searchLower)) ||
        (device.deviceCode && device.deviceCode.toLowerCase().includes(searchLower)) ||
        (device.id && device.id.toLowerCase().includes(searchLower)) ||
        (device.userName && device.userName.toLowerCase().includes(searchLower)) ||
        (device.userPhone && device.userPhone.toLowerCase().includes(searchLower))
      );
      setFilteredDevices(filtered);
    }
  }, [searchText, devices]);

  const handleDelete = (id: string) => {
    Modal.confirm({
      title: '确认删除',
      content: '确定要删除该设备吗？',
      onOk: async () => {
        try {
          // TODO: 调用删除 API
          message.success('删除功能开发中');
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
        message.success('更新功能开发中');
      } else {
        // TODO: 调用创建 API
        message.success('创建功能开发中');
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
    { title: '设备ID', dataIndex: 'id', key: 'id', width: 80 },
    { title: '设备编号', dataIndex: 'deviceCode', key: 'deviceCode' },
    { title: '设备名称', dataIndex: 'name', key: 'name' },
    {
      title: '状态',
      dataIndex: 'online',
      key: 'online',
      width: 100,
      render: (online: boolean) => (
        <Tag color={online ? 'green' : 'red'}>
          {online ? '在线' : '离线'}
        </Tag>
      )
    },
    { title: '所属用户', dataIndex: 'userName', key: 'userName' },
    { title: '用户手机', dataIndex: 'userPhone', key: 'userPhone' },
    {
      title: '最后在线',
      dataIndex: 'lastOnline',
      key: 'lastOnline',
      render: (date: string) => date ? new Date(date).toLocaleString('zh-CN') : '-'
    },
    {
      title: '操作',
      key: 'action',
      width: 250,
      fixed: 'right' as const,
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
              form.setFieldsValue({
                deviceCode: record.deviceCode,
                name: record.name
              });
              setModalVisible(true);
            }}
          >
            编辑
          </Button>
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
          <Space size="middle">
            <Input.Search
              placeholder="搜索设备名称/编号/ID/用户/手机"
              value={searchText}
              onChange={(e) => setSearchText(e.target.value)}
              allowClear
              style={{ width: 300 }}
              prefix={<SearchOutlined />}
            />
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
          </Space>
        }
      >
        <Table
          columns={columns}
          dataSource={filteredDevices}
          loading={loading}
          rowKey="id"
          scroll={{ x: 'max-content' }}
          pagination={{
            pageSize: 20,
            showSizeChanger: true,
            showQuickJumper: true,
            showTotal: (total) => `共 ${total} 条`
          }}
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
            name="deviceCode"
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
            <Descriptions.Item label="设备ID">
              {selectedDevice.id}
            </Descriptions.Item>
            <Descriptions.Item label="设备编号">
              {selectedDevice.deviceCode}
            </Descriptions.Item>
            <Descriptions.Item label="设备名称">
              {selectedDevice.name}
            </Descriptions.Item>
            <Descriptions.Item label="状态">
              <Tag color={selectedDevice.online ? 'green' : 'red'}>
                {selectedDevice.online ? '在线' : '离线'}
              </Tag>
            </Descriptions.Item>
            <Descriptions.Item label="所属用户">
              {selectedDevice.userName}
            </Descriptions.Item>
            <Descriptions.Item label="用户手机">
              {selectedDevice.userPhone || '-'}
            </Descriptions.Item>
            <Descriptions.Item label="最后在线">
              {selectedDevice.lastOnline ? new Date(selectedDevice.lastOnline).toLocaleString('zh-CN') : '-'}
            </Descriptions.Item>
          </Descriptions>
        )}
      </Modal>
    </>
  );
}
