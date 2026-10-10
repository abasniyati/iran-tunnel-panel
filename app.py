#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Iran Tunnel Management Panel
Web interface for managing Backhaul tunnels
"""

import os
import json
import subprocess
import threading
import time
import requests
from datetime import datetime
from flask import Flask, render_template, request, jsonify, session, redirect, url_for
from flask_cors import CORS
import psutil
import hashlib

app = Flask(__name__)
app.secret_key = os.urandom(24)
CORS(app)

# Configuration
CONFIG_DIR = '/opt/tunnel-panel/config'
CONFIG_FILE = f'{CONFIG_DIR}/config.json'
LOG_DIR = '/opt/tunnel-panel/logs'
BACKHAUL_BIN = '/opt/tunnel-panel/bin/backhaul'
USERS_FILE = f'{CONFIG_DIR}/users.json'

# Global state
tunnel_processes = {}
tunnel_stats = {}


class TunnelManager:
    """Manage Backhaul tunnel processes"""

    def __init__(self):
        self.config = self.load_config()
        self.load_tunnels()

    def load_config(self):
        """Load configuration from file"""
        try:
            with open(CONFIG_FILE, 'r', encoding='utf-8') as f:
                return json.load(f)
        except:
            return {}

    def save_config(self):
        """Save configuration to file"""
        try:
            with open(CONFIG_FILE, 'w', encoding='utf-8') as f:
                json.dump(self.config, f, indent=4, ensure_ascii=False)
            return True
        except Exception as e:
            print(f"Error saving config: {e}")
            return False

    def load_tunnels(self):
        """Load existing tunnels from config"""
        tunnels = self.config.get('tunnels', [])
        for tunnel in tunnels:
            if tunnel.get('auto_start', True):
                self.start_tunnel(tunnel['id'])

    def create_tunnel(self, tunnel_data):
        """Create a new tunnel configuration"""
        tunnel_id = tunnel_data.get('id') or self.generate_tunnel_id()

        tunnel = {
            'id': tunnel_id,
            'name': tunnel_data.get('name', f'Tunnel {tunnel_id}'),
            'local_port': tunnel_data.get('local_port'),
            'remote_addr': tunnel_data.get('remote_addr'),
            'protocol': tunnel_data.get('protocol', 'tcp'),
            'sni': tunnel_data.get('sni', ''),
            'keepalive': tunnel_data.get('keepalive', 20),
            'heartbeat': tunnel_data.get('heartbeat', 10),
            'retry_interval': tunnel_data.get('retry_interval', 3),
            'connection_pool': tunnel_data.get('connection_pool', 8),
            'channel_size': tunnel_data.get('channel_size', 2097152),
            'mux_session': tunnel_data.get('mux_session', 16),
            'mux_stream': tunnel_data.get('mux_stream', 4),
            'nodelay': tunnel_data.get('nodelay', True),
            'socks5_bind': tunnel_data.get('socks5_bind', '127.0.0.1:1080'),
            'auto_start': tunnel_data.get('auto_start', True),
            'created_at': datetime.now().isoformat(),
            'status': 'stopped'
        }

        if 'tunnels' not in self.config:
            self.config['tunnels'] = []

        self.config['tunnels'].append(tunnel)
        self.save_config()

        return tunnel

    def update_tunnel(self, tunnel_id, tunnel_data):
        """Update existing tunnel"""
        tunnels = self.config.get('tunnels', [])

        for i, tunnel in enumerate(tunnels):
            if tunnel['id'] == tunnel_id:
                # Stop if running
                if tunnel_id in tunnel_processes:
                    self.stop_tunnel(tunnel_id)

                # Update fields
                tunnel.update(tunnel_data)
                tunnels[i] = tunnel
                self.config['tunnels'] = tunnels
                self.save_config()

                return tunnel

        return None

    def delete_tunnel(self, tunnel_id):
        """Delete a tunnel"""
        # Stop if running
        if tunnel_id in tunnel_processes:
            self.stop_tunnel(tunnel_id)

        tunnels = self.config.get('tunnels', [])
        self.config['tunnels'] = [t for t in tunnels if t['id'] != tunnel_id]
        self.save_config()

        return True

    def start_tunnel(self, tunnel_id):
        """Start a tunnel process"""
        tunnel = self.get_tunnel(tunnel_id)
        if not tunnel:
            return False, "Tunnel not found"

        if tunnel_id in tunnel_processes:
            return False, "Tunnel already running"

        # Build Backhaul command
        cmd = self.build_backhaul_command(tunnel)

        try:
            # Start process
            process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                shell=False
            )

            tunnel_processes[tunnel_id] = {
                'process': process,
                'cmd': cmd,
                'started_at': time.time(),
                'pid': process.pid
            }

            # Update status
            self.update_tunnel_status(tunnel_id, 'running')

            # Start monitoring thread
            threading.Thread(
                target=self.monitor_tunnel,
                args=(tunnel_id,),
                daemon=True
            ).start()

            return True, f"Tunnel started with PID {process.pid}"

        except Exception as e:
            return False, f"Error starting tunnel: {str(e)}"

    def stop_tunnel(self, tunnel_id):
        """Stop a tunnel process"""
        if tunnel_id not in tunnel_processes:
            return False, "Tunnel not running"

        try:
            proc_info = tunnel_processes[tunnel_id]
            process = proc_info['process']

            # Terminate process
            process.terminate()

            # Wait for termination
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()

            del tunnel_processes[tunnel_id]

            # Update status
            self.update_tunnel_status(tunnel_id, 'stopped')

            return True, "Tunnel stopped"

        except Exception as e:
            return False, f"Error stopping tunnel: {str(e)}"

    def restart_tunnel(self, tunnel_id):
        """Restart a tunnel"""
        self.stop_tunnel(tunnel_id)
        time.sleep(1)
        return self.start_tunnel(tunnel_id)

    def build_backhaul_command(self, tunnel):
        """Build Backhaul command from tunnel config"""
        cmd = [
            BACKHAUL_BIN,
            '-c',
            '-r', tunnel['remote_addr'],
            '-l', f"127.0.0.1:{tunnel['local_port']}",
            '-t', self.config.get('security_token', ''),
            '--transport', tunnel['protocol'],
            '--keepalive', str(tunnel['keepalive']),
            '--heartbeat', str(tunnel['heartbeat']),
            '--retry-interval', str(tunnel['retry_interval']),
            '--connection-pool', str(tunnel['connection_pool']),
            '--channel-size', str(tunnel['channel_size']),
            '--mux-session', str(tunnel['mux_session']),
            '--mux-stream', str(tunnel['mux_stream']),
            '--socks5', tunnel['socks5_bind']
        ]

        if tunnel.get('sni'):
            cmd.extend(['--sni', tunnel['sni']])

        if tunnel.get('nodelay'):
            cmd.append('--nodelay')

        # Log to file
        log_file = f"{LOG_DIR}/tunnel_{tunnel['id']}.log"
        cmd.extend(['--log', log_file])

        return cmd

    def monitor_tunnel(self, tunnel_id):
        """Monitor tunnel process and collect stats"""
        while tunnel_id in tunnel_processes:
            try:
                proc_info = tunnel_processes[tunnel_id]
                process = proc_info['process']

                # Check if process is alive
                if process.poll() is not None:
                    # Process died
                    del tunnel_processes[tunnel_id]
                    self.update_tunnel_status(tunnel_id, 'stopped')
                    break

                # Collect stats
                try:
                    proc = psutil.Process(process.pid)
                    stats = {
                        'cpu_percent': proc.cpu_percent(interval=0.1),
                        'memory_mb': proc.memory_info().rss / 1024 / 1024,
                        'connections': len(proc.connections()),
                        'uptime': int(time.time() - proc_info['started_at']),
                        'status': 'running'
                    }
                    tunnel_stats[tunnel_id] = stats
                except:
                    pass

                time.sleep(2)

            except Exception as e:
                print(f"Monitor error for {tunnel_id}: {e}")
                break

    def get_tunnel(self, tunnel_id):
        """Get tunnel by ID"""
        tunnels = self.config.get('tunnels', [])
        for tunnel in tunnels:
            if tunnel['id'] == tunnel_id:
                return tunnel
        return None

    def get_all_tunnels(self):
        """Get all tunnels with current status"""
        tunnels = self.config.get('tunnels', [])

        for tunnel in tunnels:
            tunnel_id = tunnel['id']

            # Add runtime info
            if tunnel_id in tunnel_processes:
                tunnel['status'] = 'running'
                tunnel['runtime'] = tunnel_processes[tunnel_id]
            else:
                tunnel['status'] = 'stopped'

            # Add stats
            if tunnel_id in tunnel_stats:
                tunnel['stats'] = tunnel_stats[tunnel_id]

        return tunnels

    def update_tunnel_status(self, tunnel_id, status):
        """Update tunnel status in config"""
        tunnels = self.config.get('tunnels', [])
        for tunnel in tunnels:
            if tunnel['id'] == tunnel_id:
                tunnel['status'] = status
                break
        self.save_config()

    def generate_tunnel_id(self):
        """Generate unique tunnel ID"""
        import random
        import string
        while True:
            tid = ''.join(random.choices(string.ascii_lowercase + string.digits, k=8))
            if not self.get_tunnel(tid):
                return tid

    def get_xui_inbounds(self):
        """Fetch inbounds from foreign server agent"""
        try:
            agent_url = f"http://{self.config['foreign_ip']}:{self.config.get('agent_port', 8444)}"
            response = requests.get(
                f"{agent_url}/api/inbounds",
                headers={'Authorization': f"Bearer {self.config.get('security_token')}"},
                timeout=10
            )

            if response.status_code == 200:
                return response.json()
            else:
                return {'success': False, 'error': 'Agent not available'}
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def sync_with_xui(self):
        """Auto-sync tunnels with X-UI inbounds"""
        result = self.get_xui_inbounds()

        if not result.get('success'):
            return result

        inbounds = result.get('inbounds', [])
        created_count = 0

        for inbound in inbounds:
            # Check if tunnel already exists
            exists = False
            for tunnel in self.config.get('tunnels', []):
                if tunnel.get('remote_addr', '').endswith(f":{inbound['port']}"):
                    exists = True
                    break

            if not exists:
                # Create new tunnel
                tunnel_data = {
                    'name': f"{inbound['remark']} ({inbound['protocol']})",
                    'local_port': inbound['port'],
                    'remote_addr': f"{self.config['foreign_ip']}:{inbound['port']}",
                    'protocol': self.config.get('protocol', 'tcp'),
                    'auto_start': False
                }
                self.create_tunnel(tunnel_data)
                created_count += 1

        return {
            'success': True,
            'created': created_count,
            'total': len(inbounds)
        }


# Initialize manager
manager = TunnelManager()


# Authentication
def check_auth():
    """Check if user is authenticated"""
    return session.get('authenticated', False)


def load_users():
    """Load users from file"""
    try:
        if os.path.exists(USERS_FILE):
            with open(USERS_FILE, 'r') as f:
                return json.load(f)
        else:
            # Create default admin user
            default_users = {
                'admin': hashlib.sha256('admin123'.encode()).hexdigest()
            }
            with open(USERS_FILE, 'w') as f:
                json.dump(default_users, f)
            return default_users
    except:
        return {}


def save_users(users):
    """Save users to file"""
    try:
        with open(USERS_FILE, 'w') as f:
            json.dump(users, f)
        return True
    except:
        return False


# Routes
@app.route('/')
def index():
    """Main page"""
    if not check_auth():
        return redirect(url_for('login'))
    return render_template('index.html', config=manager.config)


@app.route('/login', methods=['GET', 'POST'])
def login():
    """Login page"""
    if request.method == 'POST':
        data = request.get_json() if request.is_json else request.form
        username = data.get('username')
        password = data.get('password')

        users = load_users()
        password_hash = hashlib.sha256(password.encode()).hexdigest()

        if username in users and users[username] == password_hash:
            session['authenticated'] = True
            session['username'] = username

            if request.is_json:
                return jsonify({'success': True})
            return redirect(url_for('index'))

        if request.is_json:
            return jsonify({'success': False, 'error': 'Invalid credentials'}), 401
        return render_template('login.html', error='Invalid credentials')

    return render_template('login.html')


@app.route('/logout')
def logout():
    """Logout"""
    session.clear()
    return redirect(url_for('login'))


# API Routes
@app.route('/api/tunnels', methods=['GET'])
def get_tunnels():
    """Get all tunnels"""
    if not check_auth():
        return jsonify({'error': 'Unauthorized'}), 401

    tunnels = manager.get_all_tunnels()
    return jsonify({'success': True, 'tunnels': tunnels})


@app.route('/api/tunnels', methods=['POST'])
def create_tunnel():
    """Create new tunnel"""
    if not check_auth():
        return jsonify({'error': 'Unauthorized'}), 401

    data = request.get_json()
    tunnel = manager.create_tunnel(data)

    return jsonify({'success': True, 'tunnel': tunnel})


@app.route('/api/tunnels/<tunnel_id>', methods=['PUT'])
def update_tunnel(tunnel_id):
    """Update tunnel"""
    if not check_auth():
        return jsonify({'error': 'Unauthorized'}), 401

    data = request.get_json()
    tunnel = manager.update_tunnel(tunnel_id, data)

    if tunnel:
        return jsonify({'success': True, 'tunnel': tunnel})
    return jsonify({'success': False, 'error': 'Tunnel not found'}), 404


@app.route('/api/tunnels/<tunnel_id>', methods=['DELETE'])
def delete_tunnel(tunnel_id):
    """Delete tunnel"""
    if not check_auth():
        return jsonify({'error': 'Unauthorized'}), 401

    success = manager.delete_tunnel(tunnel_id)
    return jsonify({'success': success})


@app.route('/api/tunnels/<tunnel_id>/start', methods=['POST'])
def start_tunnel(tunnel_id):
    """Start tunnel"""
    if not check_auth():
        return jsonify({'error': 'Unauthorized'}), 401

    success, message = manager.start_tunnel(tunnel_id)
    return jsonify({'success': success, 'message': message})


@app.route('/api/tunnels/<tunnel_id>/stop', methods=['POST'])
def stop_tunnel(tunnel_id):
    """Stop tunnel"""
    if not check_auth():
        return jsonify({'error': 'Unauthorized'}), 401

    success, message = manager.stop_tunnel(tunnel_id)
    return jsonify({'success': success, 'message': message})


@app.route('/api/tunnels/<tunnel_id>/restart', methods=['POST'])
def restart_tunnel(tunnel_id):
    """Restart tunnel"""
    if not check_auth():
        return jsonify({'error': 'Unauthorized'}), 401

    success, message = manager.restart_tunnel(tunnel_id)
    return jsonify({'success': success, 'message': message})


@app.route('/api/inbounds', methods=['GET'])
def get_inbounds():
    """Get X-UI inbounds from foreign server"""
    if not check_auth():
        return jsonify({'error': 'Unauthorized'}), 401

    result = manager.get_xui_inbounds()
    return jsonify(result)


@app.route('/api/inbounds/sync', methods=['POST'])
def sync_inbounds():
    """Sync tunnels with X-UI inbounds"""
    if not check_auth():
        return jsonify({'error': 'Unauthorized'}), 401

    result = manager.sync_with_xui()
    return jsonify(result)


@app.route('/api/config', methods=['GET'])
def get_config():
    """Get configuration"""
    if not check_auth():
        return jsonify({'error': 'Unauthorized'}), 401

    # Remove sensitive data
    config = manager.config.copy()
    config.pop('security_token', None)

    return jsonify({'success': True, 'config': config})


@app.route('/api/config', methods=['PUT'])
def update_config():
    """Update configuration"""
    if not check_auth():
        return jsonify({'error': 'Unauthorized'}), 401

    data = request.get_json()

    # Update config
    manager.config.update(data)
    success = manager.save_config()

    return jsonify({'success': success})


@app.route('/api/stats', methods=['GET'])
def get_stats():
    """Get system stats"""
    if not check_auth():
        return jsonify({'error': 'Unauthorized'}), 401

    stats = {
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
        'network': psutil.net_io_counters()._asdict(),
        'tunnels': tunnel_stats
    }

    return jsonify({'success': True, 'stats': stats})


@app.route('/api/password', methods=['POST'])
def change_password():
    """Change password"""
    if not check_auth():
        return jsonify({'error': 'Unauthorized'}), 401

    data = request.get_json()
    old_password = data.get('old_password')
    new_password = data.get('new_password')

    users = load_users()
    username = session.get('username')

    old_hash = hashlib.sha256(old_password.encode()).hexdigest()

    if users.get(username) != old_hash:
        return jsonify({'success': False, 'error': 'Invalid old password'}), 400

    new_hash = hashlib.sha256(new_password.encode()).hexdigest()
    users[username] = new_hash

    if save_users(users):
        return jsonify({'success': True})

    return jsonify({'success': False, 'error': 'Failed to save'}), 500


if __name__ == '__main__':
    # Ensure directories exist
    os.makedirs(CONFIG_DIR, exist_ok=True)
    os.makedirs(LOG_DIR, exist_ok=True)

    # Get port from config
    port = manager.config.get('web_port', 8443)

    # Run app
    app.run(host='0.0.0.0', port=port, debug=False)
