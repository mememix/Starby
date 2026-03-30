import { useState, useEffect } from 'react';
import { 
  Card, 
  Form, 
  Input, 
  Select, 
  Switch, 
  Button, 
  Space, 
  Divider, 
  Typography, 
  message,
  Row,
  Col,
  InputNumber
} from 'antd';
import { SaveOutlined, ReloadOutlined } from '@ant-design/icons';

const { Title, Text } = Typography;

interface Settings {
  siteName: string;
  siteDescription: string;
  maxDevicesPerUser: number;
  maxFencesPerDevice: number;
  locationRetentionDays: number;
  enableWebSocket: boolean;
  enableEmailNotification: boolean;
  defaultLanguage: string;
  timezone: string;
}

export default function Settings() {
  const [loading, setLoading] = useState(false);
  const [form] = Form.useForm();

  const initialValues: Settings = {
    siteName: '星护伙伴',
    siteDescription: '守护亲人安全的定位服务平台',
    maxDevicesPerUser: 10,
    maxFencesPerDevice: 5,
    locationRetentionDays: 30,
    enableWebSocket: true,
    enableEmailNotification: false,
    defaultLanguage: 'zh-CN',
    timezone: 'Asia/Shanghai'
  };

  useEffect(() => {
    // TODO: 从 API 加载设置
    form.setFieldsValue(initialValues);
  }, [form]);

  const handleSave = async (values: Settings) => {
    setLoading(true);
    try {
      // TODO: 调用保存设置 API
      await new Promise(resolve => setTimeout(resolve, 1000));
      message.success('设置保存成功');
    } catch (error) {
      message.error('保存失败');
    } finally {
      setLoading(false);
    }
  };

  const handleReset = () => {
    form.setFieldsValue(initialValues);
    message.info('已重置为默认值');
  };

  return (
    <div>
      <Card>
        <div style={{ marginBottom: 24 }}>
          <Title level={4}>系统设置</Title>
          <Text type="secondary">配置系统基础参数和运行环境</Text>
        </div>

        <Form
          form={form}
          layout="vertical"
          onFinish={handleSave}
          initialValues={initialValues}
        >
          <Divider orientation="left">基本信息</Divider>
          <Row gutter={16}>
            <Col xs={24} md={12}>
              <Form.Item
                name="siteName"
                label="网站名称"
                rules={[{ required: true, message: '请输入网站名称' }]}
              >
                <Input placeholder="请输入网站名称" />
              </Form.Item>
            </Col>
            <Col xs={24} md={12}>
              <Form.Item
                name="defaultLanguage"
                label="默认语言"
              >
                <Select>
                  <Select.Option value="zh-CN">简体中文</Select.Option>
                  <Select.Option value="en-US">English</Select.Option>
                </Select>
              </Form.Item>
            </Col>
          </Row>

          <Form.Item
            name="siteDescription"
            label="网站描述"
          >
            <Input.TextArea 
              rows={3} 
              placeholder="请输入网站描述"
            />
          </Form.Item>

          <Divider orientation="left">用户限制</Divider>
          <Row gutter={16}>
            <Col xs={24} md={8}>
              <Form.Item
                name="maxDevicesPerUser"
                label="每用户最大设备数"
                rules={[{ required: true, message: '请输入' }]}
              >
                <InputNumber 
                  min={1} 
                  max={100} 
                  style={{ width: '100%' }}
                  placeholder="请输入"
                />
              </Form.Item>
            </Col>
            <Col xs={24} md={8}>
              <Form.Item
                name="maxFencesPerDevice"
                label="每设备最大围栏数"
                rules={[{ required: true, message: '请输入' }]}
              >
                <InputNumber 
                  min={1} 
                  max={50} 
                  style={{ width: '100%' }}
                  placeholder="请输入"
                />
              </Form.Item>
            </Col>
            <Col xs={24} md={8}>
              <Form.Item
                name="locationRetentionDays"
                label="位置数据保留天数"
                rules={[{ required: true, message: '请输入' }]}
              >
                <InputNumber 
                  min={1} 
                  max={365} 
                  style={{ width: '100%' }}
                  placeholder="请输入"
                />
              </Form.Item>
            </Col>
          </Row>

          <Divider orientation="left">功能开关</Divider>
          <Row gutter={16}>
            <Col xs={24} md={12}>
              <Form.Item
                name="enableWebSocket"
                label="WebSocket 实时推送"
                valuePropName="checked"
              >
                <Switch />
              </Form.Item>
            </Col>
            <Col xs={24} md={12}>
              <Form.Item
                name="enableEmailNotification"
                label="邮件通知"
                valuePropName="checked"
              >
                <Switch />
              </Form.Item>
            </Col>
          </Row>

          <Divider orientation="left">时区设置</Divider>
          <Row gutter={16}>
            <Col xs={24} md={12}>
              <Form.Item
                name="timezone"
                label="系统时区"
              >
                <Select>
                  <Select.Option value="Asia/Shanghai">Asia/Shanghai (北京)</Select.Option>
                  <Select.Option value="Asia/Tokyo">Asia/Tokyo (东京)</Select.Option>
                  <Select.Option value="America/New_York">America/New_York (纽约)</Select.Option>
                  <Select.Option value="Europe/London">Europe/London (伦敦)</Select.Option>
                </Select>
              </Form.Item>
            </Col>
          </Row>

          <Divider />

          <Form.Item>
            <Space>
              <Button 
                type="primary" 
                icon={<SaveOutlined />}
                htmlType="submit"
                loading={loading}
                size="large"
              >
                保存设置
              </Button>
              <Button 
                icon={<ReloadOutlined />}
                onClick={handleReset}
                size="large"
              >
                重置默认
              </Button>
            </Space>
          </Form.Item>
        </Form>
      </Card>
    </div>
  );
}
