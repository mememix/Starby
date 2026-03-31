#!/usr/bin/env python3
"""
文件上传接口测试脚本
用于上传用户头像和设备头像
"""

import os
import sys
import requests
import json
from pathlib import Path

# 配置
API_BASE = "http://localhost:3000"
PHONE = "18201162729"
PASSWORD = "123456"
DEVICE_ID = "1528"  # 设备37374552877的ID

def login():
    """登录获取Token"""
    print("=" * 50)
    print("  文件上传接口测试")
    print("=" * 50)
    print()

    print("[1/4] 正在登录...")
    url = f"{API_BASE}/api/auth/login"
    data = {
        "phone": PHONE,
        "password": PASSWORD
    }

    response = requests.post(url, json=data)

    if response.status_code != 200:
        print(f"❌ 登录失败: {response.status_code}")
        print(f"响应: {response.text}")
        sys.exit(1)

    result = response.json()
    if not result.get('success'):
        print(f"❌ 登录失败: {result.get('message')}")
        sys.exit(1)

    token = result.get('data', {}).get('token')
    if not token:
        print(f"❌ 无法获取Token")
        sys.exit(1)

    print(f"✓ 登录成功")
    print(f"Token: {token[:20]}...")
    print()

    return token

def upload_device_avatar(token):
    """上传设备头像"""
    print("[3/4] 上传设备头像...")

    device_image_path = "/tmp/device_37374552877.jpg"
    if not os.path.exists(device_image_path):
        print(f"❌ 设备图片不存在: {device_image_path}")
        return False

    file_size = os.path.getsize(device_image_path)
    print(f"文件: {device_image_path}")
    print(f"大小: {file_size} bytes ({file_size / 1024:.2f} KB)")

    url = f"{API_BASE}/api/upload/device-avatar/{DEVICE_ID}"
    headers = {
        "Authorization": f"Bearer {token}"
    }

    try:
        with open(device_image_path, 'rb') as f:
            files = {'avatar': ('device_37374552877.jpg', f, 'image/jpeg')}
            response = requests.post(url, headers=headers, files=files)
    except Exception as e:
        print(f"❌ 上传失败: {e}")
        return False

    print(f"响应: {json.dumps(response.json(), indent=2, ensure_ascii=False)}")
    print()

    if response.status_code == 200 and response.json().get('success'):
        print("✓ 设备头像上传成功")
        return True
    else:
        print(f"❌ 设备头像上传失败: {response.status_code}")
        return False

def upload_user_avatar(token):
    """上传用户头像"""
    print("[4/4] 上传用户头像...")

    # 使用设备图片作为用户头像（实际使用时应该使用不同的图片）
    device_image_path = "/tmp/device_37374552877.jpg"
    if not os.path.exists(device_image_path):
        print(f"❌ 图片不存在: {device_image_path}")
        return False

    file_size = os.path.getsize(device_image_path)
    print(f"文件: {device_image_path}")
    print(f"大小: {file_size} bytes ({file_size / 1024:.2f} KB)")

    url = f"{API_BASE}/api/upload/user-avatar"
    headers = {
        "Authorization": f"Bearer {token}"
    }

    try:
        with open(device_image_path, 'rb') as f:
            files = {'avatar': ('user_avatar.jpg', f, 'image/jpeg')}
            response = requests.post(url, headers=headers, files=files)
    except Exception as e:
        print(f"❌ 上传失败: {e}")
        return False

    print(f"响应: {json.dumps(response.json(), indent=2, ensure_ascii=False)}")
    print()

    if response.status_code == 200 and response.json().get('success'):
        print("✓ 用户头像上传成功")
        return True
    else:
        print(f"❌ 用户头像上传失败: {response.status_code}")
        return False

def check_database():
    """检查数据库中的头像信息"""
    print("[2/4] 检查数据库中的头像信息...")

    try:
        from prisma import Client

        prisma = Client()

        # 查询设备
        device = prisma.device.find_first(
            where={'deviceCode': '37374552877'}
        )

        if device:
            print(f"✓ 找到设备:")
            print(f"  设备ID: {device.deviceId}")
            print(f"  设备号: {device.deviceCode}")
            print(f"  设备名: {device.deviceName}")
            print(f"  当前头像: {device.avatar[:50] if device.avatar else 'None'}...")
        else:
            print("❌ 未找到设备")

        prisma.disconnect()
        print()

    except Exception as e:
        print(f"⚠️  数据库查询失败: {e}")
        print()

def main():
    """主函数"""
    try:
        # 1. 登录
        token = login()

        # 2. 检查数据库
        check_database()

        # 3. 上传设备头像
        device_success = upload_device_avatar(token)

        # 4. 上传用户头像
        user_success = upload_user_avatar(token)

        # 总结
        print("=" * 50)
        print("  测试完成")
        print("=" * 50)
        print()

        if device_success and user_success:
            print("✓ 所有头像上传成功！")
        elif device_success:
            print("⚠️  设备头像上传成功，用户头像上传失败")
        elif user_success:
            print("⚠️  用户头像上传成功，设备头像上传失败")
        else:
            print("❌ 所有头像上传失败")

    except KeyboardInterrupt:
        print("\n\n用户中断")
        sys.exit(0)
    except Exception as e:
        print(f"\n\n❌ 错误: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    main()
