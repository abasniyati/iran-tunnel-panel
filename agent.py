#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Foreign Server Agent
Provides API for Iran server to fetch X-UI inbounds and server status
"""

import os
import json
import requests
import psutil
from datetime import datetime
from flask import Flask, request, jsonify
import subprocess
import time

app = Flask(__name__)

# Configuration
CONFIG_DIR = '/opt/tunnel-panel/config'
CONFIG_FILE = f'{CONFIG_DIR}/config.json'
LOG_DIR = '/opt/tunnel-panel/logs'
BACKHAUL_BIN = '/opt/tunnel-panel/bin/backhaul'

# Global state
backhaul_process = None
server_stats = {}


class AgentManager:
    """Manage agent operations"""

    def __init__(self):
        self.config = self.load_config()
        self.start_backhaul_server()

    def load_config(self):
        """Load configuration"""
        try:
            with open(CONFIG_FILE, 'r', encoding='utf-8') as f:
                return json.load(f)
        except:
            return {}

    def start_backhaul_server(self):
        """Start Backhaul server"""
        global backhaul_process

        if backhaul_process:
            return

        try:
            # Build command
            cmd = [
                BACKHAUL_BIN,
                '-s',
                '-b', f"0.0.0.0:{self.config.get('listen_port', 8080)}",
                '-t', self.config.get('security_token', ''),
                '--transport', 'tcp',
                '--log', f'{LOG_DIR}/backhaul_server.log'
            ]

            # Start process
            backhaul_process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE
            )

            print(f"Backhaul server started with PID {backhaul_process.pid}")

            # Start monitoring
            import threading
            threading.Thread(target=self.monitor_backhaul, daemon=True).start()

        except Exception as e:
            print(f"Error starting Backhaul server: {e}")

    def monitor_backhaul(self):
        """Monitor Backhaul process"""
        global backhaul_process, server_stats

        while True:
            try:
                if backhaul_process and backhaul_process.poll() is None:
                    # Process is running
                    try:
                        proc = psutil.Process(backhaul_process.pid)
                        server_stats['backhaul'] = {
                            'status': 'running',
                            'pid': backhaul_process.pid,
                            'cpu_percent': proc.cpu_percent(interval=0.1),
                            'memory_mb': proc.memory_info().rss / 1024 / 1024,
                            'connections': len(proc.connections())
                        }
                    except:
                        pass
                else:
                    # Process died, restart
                    server_stats['backhaul'] = {'status': 'stopped'}
                    print("Backhaul server died, restarting...")
                    backhaul_process = None
                    time.sleep(5)
                    self.start_backhaul_server()

                time.sleep(3)

            except Exception as e:
                print(f"Monitor error: {e}")
                time.sleep(5)

    def get_xui_inbounds(self):
        """Fetch inbounds from X-UI panel"""
        if not self.config.get('xui_enabled', False):
            return {'success': False, 'error': 'X-UI not configured'}

        try:
            xui_url = f"http://127.0.0.1:{self.config.get('xui_port', 54321)}"
            username = self.config.get('xui_username')
            password = self.config.get('xui_password')

            # Login to X-UI
            session = requests.Session()
            login_response = session.post(
                f"{xui_url}/login",
                data={'username': username, 'password': password},
                timeout=10
            )

            if login_response.status_code != 200:
                return {'success': False, 'error': 'X-UI login failed'}

            # Get inbounds list
            inbounds_response = session.post(
                f"{xui_url}/panel/api/inbounds/list",
                timeout=10
            )

            if inbounds_response.status_code == 200:
                data = inbounds_response.json()

                if data.get('success'):
                    inbounds = data.get('obj', [])

                    # Format inbounds
                    formatted = []
                    for inbound in inbounds:
                        formatted.append({
                            'id': inbound.get('id'),
                            'port': inbound.get('port'),
                            'protocol': inbound.get('protocol'),
                            'remark': inbound.get('remark', f"Port {inbound.get('port')}"),
                            'enable': inbound.get('enable', False),
                            'up': inbound.get('up', 0),
                            'down': inbound.get('down', 0),
                            'total': inbound.get('total', 0),
                            'expiry_time': inbound.get('expiryTime', 0)
                        })

                    return {
                        'success': True,
                        'inbounds': formatted
                    }

            return {'success': False, 'error': 'Failed to fetch inbounds'}

        except requests.exceptions.Timeout:
            return {'success': False, 'error': 'X-UI connection timeout'}
        except requests.exceptions.ConnectionError:
            return {'success': False, 'error': 'Cannot connect to X-UI'}
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def get_server_stats(self):
        """Get server statistics"""
        try:
            stats = {
                'timestamp': datetime.now().isoformat(),
                'cpu_percent': psutil.cpu_percent(interval=1),
                'memory': {
                    'total': psutil.virtual_memory().total,
                    'used': psutil.virtual_memory().used,
                    'percent': psutil.virtual_memory().percent
                },
                'disk': {
                    'total': psutil.disk_usage('/').total,
                    'used': psutil.disk_usage('/').used,
                    'percent': psutil.disk_usage('/').percent
                },
                'network': {
                    'bytes_sent': psutil.net_io_counters().bytes_sent,
                    'bytes_recv': psutil.net_io_counters().bytes_recv,
                    'packets_sent': psutil.net_io_counters().packets_sent,
                    'packets_recv': psutil.net_io_counters().packets_recv
                },
                'backhaul': server_stats.get('backhaul', {'status': 'unknown'})
            }

            return {'success': True, 'stats': stats}

        except Exception as e:
            return {'success': False, 'error': str(e)}

    def add_manual_inbound(self, inbound_data):
        """Add manual inbound to list"""
        try:
            inbounds = self.config.get('inbounds', [])

            # Check if already exists
            for inbound in inbounds:
                if inbound.get('port') == inbound_data.get('port'):
                    return {'success': False, 'error': 'Inbound already exists'}

            # Add new inbound
            inbounds.append({
                'port': inbound_data.get('port'),
                'protocol': inbound_data.get('protocol', 'vmess'),
                'remark': inbound_data.get('remark', f"Port {inbound_data.get('port')}"),
                'manual': True,
                'created_at': datetime.now().isoformat()
            })

            self.config['inbounds'] = inbounds
            self.save_config()

            return {'success': True, 'message': 'Inbound added'}

        except Exception as e:
            return {'success': False, 'error': str(e)}

    def get_manual_inbounds(self):
        """Get manually added inbounds"""
        try:
            inbounds = self.config.get('inbounds', [])
            manual_inbounds = [ib for ib in inbounds if ib.get('manual', False)]

            return {
                'success': True,
                'inbounds': manual_inbounds
            }

        except Exception as e:
            return {'success': False, 'error': str(e)}

    def save_config(self):
        """Save configuration"""
        try:
            with open(CONFIG_FILE, 'w', encoding='utf-8') as f:
                json.dump(self.config, f, indent=4, ensure_ascii=False)
            return True
        except Exception as e:
            print(f"Error saving config: {e}")
            return False


# Initialize manager
manager = AgentManager()


# Middleware: Check authentication
def check_token():
    """Verify security token"""
    auth_header = request.headers.get('Authorization', '')

    if not auth_header.startswith('Bearer '):
        return False

    token = auth_header.replace('Bearer ', '')
    expected_token = manager.config.get('security_token', '')

    return token == expected_token


# Routes
@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({
        'success': True,
        'status': 'healthy',
        'timestamp': datetime.now().isoformat()
    })


@app.route('/api/inbounds', methods=['GET'])
def get_inbounds():
    """Get X-UI inbounds"""
    if not check_token():
        return jsonify({'success': False, 'error': 'Unauthorized'}), 401

    # Try to get from X-UI
    result = manager.get_xui_inbounds()

    if not result.get('success'):
        # Fallback to manual inbounds
        result = manager.get_manual_inbounds()

    return jsonify(result)


@app.route('/api/inbounds', methods=['POST'])
def add_inbound():
    """Add manual inbound"""
    if not check_token():
        return jsonify({'success': False, 'error': 'Unauthorized'}), 401

    data = request.get_json()
    result = manager.add_manual_inbound(data)

    return jsonify(result)


@app.route('/api/stats', methods=['GET'])
def get_stats():
    """Get server statistics"""
    if not check_token():
        return jsonify({'success': False, 'error': 'Unauthorized'}), 401

    result = manager.get_server_stats()
    return jsonify(result)


@app.route('/api/backhaul/status', methods=['GET'])
def backhaul_status():
    """Get Backhaul server status"""
    if not check_token():
        return jsonify({'success': False, 'error': 'Unauthorized'}), 401

    status = server_stats.get('backhaul', {'status': 'unknown'})
    return jsonify({'success': True, 'status': status})


@app.route('/api/backhaul/restart', methods=['POST'])
def restart_backhaul():
    """Restart Backhaul server"""
    if not check_token():
        return jsonify({'success': False, 'error': 'Unauthorized'}), 401

    global backhaul_process

    try:
        if backhaul_process:
            backhaul_process.terminate()
            try:
                backhaul_process.wait(timeout=5)
            except:
                backhaul_process.kill()

            backhaul_process = None

        time.sleep(2)
        manager.start_backhaul_server()

        return jsonify({'success': True, 'message': 'Backhaul restarted'})

    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})


if __name__ == '__main__':
    # Ensure directories exist
    os.makedirs(CONFIG_DIR, exist_ok=True)
    os.makedirs(LOG_DIR, exist_ok=True)

    # Get port from config
    port = manager.config.get('agent_port', 8444)

    print(f"Agent starting on port {port}...")
    print(f"Backhaul server listening on port {manager.config.get('listen_port', 8080)}")

    # Run app
    app.run(host='0.0.0.0', port=port, debug=False)
