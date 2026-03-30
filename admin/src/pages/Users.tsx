import { useState, useEffect } from 'react';
import { Table, Space, Button, Card, Tag, Modal, Form, Input, message } from 'antd';
import { PlusOutlined, EditOutlined, DeleteOutlined } from '@ant-design/icons';
import api from '../utils/api';

interface User {
  id: string;
  phone: string;
  createdAt: string;
  deviceCount?: number;
}

export default function Users() {
  const [loading, setLoading] = useState(false);
  const [users, setUsers] = useState<User[]>([]);
  const [modalVisible, setModalVisible] = useState(false);
  const [editingUser, setEditingUser] = useState<User | null>(null);
  const [form] = Form.useForm();

  const loadUsers = async () => {
    setLoading(true);
    try {
      // TODO: 从 API 获取用户列表
      // const response = await api.get('/users');
      // setUsers(response.data.users);
      
      // 模拟数据
      setUsers([
        { id: '1', phone: '13800138001', createdAt: '2026-03-01', deviceCount: 2 },
        { id: '2', phone: '13800138002', createdAt: '2026-03-05', deviceCount: 1 },
        { id: '3', phone: '13800138003', createdAt: '2026-03-10', deviceCount: 3 }
      ]);
    } catch (error) {
      message.error('加载用户失败');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadUsers();
  }, []);

  const handleDelete = (id: string) => {
    Modal.confirm({
      title: '确认删除',
      content: '确定要删除该用户吗？',
      onOk: async () => {
        try {
          // TODO: 调用删除 API
          message.success('删除成功');
          loadUsers();
        } catch (error) {
          message.error('删除失败');
        }
      }
    });
  };

  const handleSubmit = async (values: any) => {
    try {
      if (editingUser) {
        // TODO: 调用更新 API
        message.success('更新成功');
      } else {
        // TODO: 调用创建 API
        message.success('创建成功');
      }
      setModalVisible(false);
      form.resetFields();
      loadUsers();
    } catch (error) {
      message.error('操作失败');
    }
  };

  const columns = [
    { title: 'ID', dataIndex: 'id', key: 'id' },
    { title: '手机号', dataIndex: 'phone', key: 'phone' },
    { 
      title: '设备数', 
      dataIndex: 'deviceCount', 
      key: 'deviceCount',
      render: (count: number) => <Tag color="blue">{count}</Tag>
    },
    { title: '注册时间', dataIndex: 'createdAt', key: 'createdAt' },
    {
      title: '操作',
      key: 'action',
      render: (_: any, record: User) => (
        <Space size="middle">
          <Button 
            type="link" 
            icon={<EditOutlined />}
            onClick={() => {
              setEditingUser(record);
              form.setFieldsValue(record);
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
    <Card 
      title="用户管理"
      extra={
        <Button 
          type="primary" 
          icon={<PlusOutlined />}
          onClick={() => {
            setEditingUser(null);
            form.resetFields();
            setModalVisible(true);
          }}
        >
          添加用户
        </Button>
      }
    >
      <Table 
        columns={columns} 
        dataSource={users}
        loading={loading}
        rowKey="id"
      />

      <Modal
        title={editingUser ? '编辑用户' : '添加用户'}
        open={modalVisible}
        onCancel={() => setModalVisible(false)}
        footer={null}
      >
        <Form
          form={form}
          layout="vertical"
          onFinish={handleSubmit}
        >
          <Form.Item
            name="phone"
            label="手机号"
            rules={[{ required: true, message: '请输入手机号' }]}
          >
            <Input placeholder="请输入手机号" />
          </Form.Item>
          {!editingUser && (
            <Form.Item
              name="password"
              label="密码"
              rules={[{ required: true, message: '请输入密码' }]}
            >
              <Input.Password placeholder="请输入密码" />
            </Form.Item>
          )}
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
    </Card>
  );
}
