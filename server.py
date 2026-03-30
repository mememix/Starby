#!/usr/bin/env python3
"""
星护伙伴项目 - 安全文件服务器
功能：提供加密的文件访问服务
访问地址：https://localhost:8443 或 http://localhost:8080
"""

import http.server
import socketserver
import base64
import ssl
import os
from pathlib import Path

# 配置
PORT_HTTP = 8080      # HTTP端口（建议只用HTTPS）
PORT_HTTPS = 8443     # HTTPS端口
USERNAME = "xinghu"   # 访问用户名
PASSWORD = "xinghu123" # 访问密码（生产环境请修改）
SERVE_DIR = "/Users/mememix/.openclaw/workspace/xinghu-app"

class AuthHandler(http.server.SimpleHTTPRequestHandler):
    """带Basic Auth的HTTP处理器"""
    
    def do_AUTH(self):
        """发送认证请求"""
        self.send_response(401)
        self.send_header('WWW-Authenticate', 'Basic realm="Xinghu App"')
        self.send_header('Content-type', 'text/html')
        self.end_headers()
        self.wfile.write(b'Authentication required')
    
    def authenticate(self):
        """验证用户名密码"""
        auth_header = self.headers.get('Authorization')
        if auth_header is None:
            self.do_AUTH()
            return False
        
        try:
            # 解析 Basic auth
            auth_type, auth_string = auth_header.split(' ', 1)
            if auth_type.lower() != 'basic':
                self.do_AUTH()
                return False
            
            # 解码验证
            decoded = base64.b64decode(auth_string).decode('utf-8')
            username, password = decoded.split(':', 1)
            
            if username == USERNAME and password == PASSWORD:
                return True
            else:
                self.do_AUTH()
                return False
        except Exception:
            self.do_AUTH()
            return False
    
    def do_GET(self):
        """处理GET请求"""
        if not self.authenticate():
            return
        
        # 修改工作目录到项目目录
        os.chdir(SERVE_DIR)
        super().do_GET()
    
    def do_HEAD(self):
        """处理HEAD请求"""
        if not self.authenticate():
            return
        os.chdir(SERVE_DIR)
        super().do_HEAD()
    
    def log_message(self, format, *args):
        """自定义日志"""
        print(f"[{self.log_date_time_string()}] {self.client_address[0]} - {format % args}")

def generate_ssl_cert():
    """生成自签名SSL证书"""
    cert_path = "/Users/mememix/.openclaw/workspace/xinghu-app/server.pem"
    
    if os.path.exists(cert_path):
        print(f"✓ SSL证书已存在: {cert_path}")
        return cert_path
    
    print("⚙️  生成SSL证书...")
    os.system(f"""
    openssl req -new -x509 -keyout {cert_path} -out {cert_path} \
    -days 365 -nodes \
    -subj "/C=CN/ST=Beijing/L=Beijing/O=Xinghu/OU=Dev/CN=localhost" \
    2>/dev/null
    """)
    print(f"✓ SSL证书已生成: {cert_path}")
    return cert_path

def start_http_server():
    """启动HTTP服务器（不推荐，仅用于测试）"""
    with socketserver.TCPServer(("", PORT_HTTP), AuthHandler) as httpd:
        print(f"\n🚀 HTTP服务器已启动")
        print(f"📍 访问地址: http://localhost:{PORT_HTTP}")
        print(f"📂 服务目录: {SERVE_DIR}")
        print(f"🔑 用户名: {USERNAME}")
        print(f"🔑 密码: {PASSWORD}")
        print(f"\n⚠️  警告: HTTP不安全，建议使用HTTPS\n")
        httpd.serve_forever()

def start_https_server():
    """启动HTTPS服务器（推荐）"""
    cert_path = generate_ssl_cert()
    
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain(cert_path)
    
    with socketserver.TCPServer(("", PORT_HTTPS), AuthHandler) as httpd:
        httpd.socket = context.wrap_socket(httpd.socket, server_side=True)
        print(f"\n🔒 HTTPS服务器已启动")
        print(f"📍 访问地址: https://localhost:{PORT_HTTPS}")
        print(f"📂 服务目录: {SERVE_DIR}")
        print(f"🔑 用户名: {USERNAME}")
        print(f"🔑 密码: {PASSWORD}")
        print(f"\n✅ 安全提示:")
        print(f"   - 所有传输已加密 (HTTPS)")
        print(f"   - 需要用户名密码认证")
        print(f"   - 访问日志已启用\n")
        httpd.serve_forever()

if __name__ == "__main__":
    import sys
    
    # 确保服务目录存在
    Path(SERVE_DIR).mkdir(parents=True, exist_ok=True)
    
    print("=" * 50)
    print("  星护伙伴项目 - 安全文件服务器")
    print("=" * 50)
    
    if len(sys.argv) > 1 and sys.argv[1] == "--http":
        start_http_server()
    else:
        start_https_server()
