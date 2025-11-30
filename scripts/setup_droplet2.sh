#!/bin/bash
set -e

echo "🚀 Setting up DigitalOcean Droplet 2 for Jenkins deployment..."
echo "📁 Application directory: /root/blog-app"
echo "📝 Logs directory: /root/blog-app/logs"
echo ""

# Update system
echo "📦 Updating system packages..."
sudo apt-get update
sudo apt-get upgrade -y

# Install required packages
echo "📦 Installing required packages..."
sudo apt-get install -y python3 python3-pip python3-venv git nginx curl

# Install MongoDB
echo "🍃 Installing MongoDB..."
curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | sudo gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list
sudo apt-get update
sudo apt-get install -y mongodb-org
sudo systemctl start mongod
sudo systemctl enable mongod

echo "⏳ Waiting for MongoDB to be ready..."
sleep 5

# Verify MongoDB is running
if sudo systemctl is-active --quiet mongod; then
    echo "✅ MongoDB is running"
else
    echo "❌ MongoDB failed to start"
    sudo systemctl status mongod
    exit 1
fi

# Create application directory
echo "📁 Creating application directory..."
mkdir -p /root/blog-app
cd /root/blog-app

# Clone repository (if not already cloned)
if [ ! -d "/root/blog-app/.git" ]; then
    echo "📥 Cloning repository..."
    git clone YOUR_REPO_URL .
else
    echo "ℹ️  Repository already exists, pulling latest changes..."
    git pull origin main
fi

# Create logs directory
echo "📝 Creating logs directory..."
mkdir -p /root/blog-app/logs

# Create virtual environment
echo "🐍 Setting up Python virtual environment..."
python3 -m venv venv
source venv/bin/activate

# Upgrade pip
pip install --upgrade pip

# Install dependencies
echo "📦 Installing Python dependencies..."
pip install -r requirements.txt

# Verify gunicorn is installed
if [ -f "/root/blog-app/venv/bin/gunicorn" ]; then
    echo "✅ Gunicorn installed successfully"
else
    echo "⚠️  Gunicorn not found, installing explicitly..."
    pip install gunicorn
fi

# Generate a random secret key (different from Droplet 1)
echo "🔐 Generating SECRET_KEY..."
SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_hex(32))")

# Create .env file with generated secret key
echo "📝 Creating .env file..."
cat > .env << EOF
SECRET_KEY=${SECRET_KEY}
MONGO_URI=mongodb://localhost:27017/
DATABASE_NAME=blog_db
FLASK_ENV=production
FLASK_DEBUG=False
EOF

echo "✅ Created .env file with auto-generated SECRET_KEY"
echo "   SECRET_KEY: ${SECRET_KEY}"

# Make .env readable
chmod 644 .env

# Deactivate venv
deactivate

# Install systemd service
echo "⚙️  Installing systemd service..."
sudo tee /etc/systemd/system/blog-app.service > /dev/null << 'EOF'
[Unit]
Description=Blog Flask Application
After=network.target mongod.service

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=/root/blog-app
Environment="PATH=/root/blog-app/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
EnvironmentFile=/root/blog-app/.env
ExecStart=/root/blog-app/venv/bin/gunicorn \
    --bind 0.0.0.0:5000 \
    --workers 4 \
    --timeout 120 \
    --access-logfile /root/blog-app/logs/access.log \
    --error-logfile /root/blog-app/logs/error.log \
    app:app
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

echo "✅ Systemd service file created"

# Reload systemd
sudo systemctl daemon-reload

# Enable the service
sudo systemctl enable blog-app

# Test the application manually first
echo ""
echo "🧪 Testing application manually before starting service..."
cd /root/blog-app
source venv/bin/activate
export $(cat .env | xargs)

# Test import
python3 << 'PYTEST'
import sys
sys.path.insert(0, '/root/blog-app')
try:
    from app import app
    print("✅ Application imports successfully")
except Exception as e:
    print(f"❌ Import error: {e}")
    sys.exit(1)
PYTEST

if [ $? -ne 0 ]; then
    echo "❌ Application has import errors. Please check your code."
    exit 1
fi

deactivate

# Start the service
echo ""
echo "🚀 Starting blog-app service..."
sudo systemctl start blog-app

# Wait for application to start
echo "⏳ Waiting for application to start..."
sleep 8

# Check if application started successfully
if sudo systemctl is-active --quiet blog-app; then
    echo "✅ Application service is running!"
else
    echo "⚠️  Application failed to start. Checking logs..."
    echo ""
    echo "=== Service Status ==="
    sudo systemctl status blog-app --no-pager -l
    echo ""
    echo "=== Last 30 log lines ==="
    sudo journalctl -u blog-app -n 30 --no-pager
    echo ""
    echo "=== Application error logs ==="
    if [ -f /root/blog-app/logs/error.log ]; then
        tail -20 /root/blog-app/logs/error.log
    fi
    echo ""
    echo "❌ Setup failed. Please review the errors above."
    exit 1
fi

# Configure Nginx
echo ""
echo "🌐 Configuring Nginx..."
sudo tee /etc/nginx/sites-available/blog-app > /dev/null << 'EOF'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /metrics {
        proxy_pass http://127.0.0.1:5000/metrics;
        allow all;
    }

    location /health {
        proxy_pass http://127.0.0.1:5000/health;
        access_log off;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/blog-app /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Test nginx configuration
if sudo nginx -t; then
    echo "✅ Nginx configuration is valid"
    sudo systemctl restart nginx
    echo "✅ Nginx restarted"
else
    echo "❌ Nginx configuration error"
    exit 1
fi

# Setup firewall
echo ""
echo "🔥 Configuring firewall..."
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 5000/tcp
sudo ufw --force enable
echo "✅ Firewall configured"

# Install MongoDB exporter
echo ""
echo "📊 Installing MongoDB exporter..."
cd /tmp
wget -q https://github.com/percona/mongodb_exporter/releases/download/v0.40.0/mongodb_exporter-0.40.0.linux-amd64.tar.gz
tar xzf mongodb_exporter-0.40.0.linux-amd64.tar.gz
sudo mv mongodb_exporter /usr/local/bin/
rm mongodb_exporter-0.40.0.linux-amd64.tar.gz

# Create MongoDB exporter service
sudo tee /etc/systemd/system/mongodb-exporter.service > /dev/null << 'EOF'
[Unit]
Description=MongoDB Exporter
After=network.target mongod.service

[Service]
Type=simple
User=mongodb
ExecStart=/usr/local/bin/mongodb_exporter --mongodb.uri=mongodb://localhost:27017
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable mongodb-exporter
sudo systemctl start mongodb-exporter

echo ""
echo "=========================================="
echo "  Setup Complete!"
echo "=========================================="
echo ""

# Show final status
echo "📊 Service Status:"
echo "  MongoDB:         $(sudo systemctl is-active mongod)"
echo "  Blog App:        $(sudo systemctl is-active blog-app)"
echo "  Nginx:           $(sudo systemctl is-active nginx)"
echo "  MongoDB Exp:     $(sudo systemctl is-active mongodb-exporter)"
echo ""

# Test the application
echo "🧪 Testing application endpoints..."
sleep 3

HEALTH_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5000/health)
if [ "$HEALTH_STATUS" = "200" ]; then
    echo "✅ Health endpoint responding (HTTP 200)"
    curl -s http://localhost:5000/health
    echo ""
else
    echo "⚠️  Health endpoint returned HTTP $HEALTH_STATUS"
fi

METRICS_STATUS=$(curl -s http://localhost:5000/metrics | grep -c "blog_")
if [ "$METRICS_STATUS" -gt 0 ]; then
    echo "✅ Metrics endpoint responding ($METRICS_STATUS metrics found)"
else
    echo "⚠️  Metrics endpoint not responding properly"
fi

HOME_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5000/)
if [ "$HOME_STATUS" = "200" ]; then
    echo "✅ Homepage responding (HTTP 200)"
else
    echo "⚠️  Homepage returned HTTP $HOME_STATUS"
fi

echo ""
echo "📝 Important Information:"
echo "  Application Directory: /root/blog-app"
echo "  Logs Directory: /root/blog-app/logs"
echo "  Access Logs: /root/blog-app/logs/access.log"
echo "  Error Logs: /root/blog-app/logs/error.log"
echo "  Environment File: /root/blog-app/.env"
echo "  SECRET_KEY: ${SECRET_KEY}"
echo "  MongoDB URI: mongodb://localhost:27017/"
echo "  Database Name: blog_db"
echo ""

echo "📝 Next steps:"
echo "1. Generate SSH key for Jenkins:"
echo "   ssh-keygen -t ed25519 -C 'jenkins' -f ~/.ssh/jenkins_key -N ''"
echo "   cat ~/.ssh/jenkins_key.pub >> ~/.ssh/authorized_keys"
echo "   cat ~/.ssh/jenkins_key  # Copy this for Jenkins credentials"
echo ""
echo "2. Configure Jenkins credentials:"
echo "   - droplet2-host: $(curl -s ifconfig.me)"
echo "   - droplet2-user: root"
echo "   - droplet2-ssh-key: <private key from above>"
echo "   - droplet2-app-dir: /root/blog-app"
echo "   - mongo-uri: mongodb://localhost:27017/"
echo "   - secret-key: <generate a new one>"
echo "   - database-name: blog_db"
echo ""
echo "3. Update monitoring/prometheus.yml with this droplet's IP: $(curl -s ifconfig.me)"
echo ""
echo "🔍 Useful commands:"
echo "  Check service status:    sudo systemctl status blog-app"
echo "  View live logs:          sudo journalctl -u blog-app -f"
echo "  View error logs:         tail -f /root/blog-app/logs/error.log"
echo "  View access logs:        tail -f /root/blog-app/logs/access.log"
echo "  Restart application:     sudo systemctl restart blog-app"
echo "  Test health endpoint:    curl http://localhost:5000/health"
echo "  Test metrics endpoint:   curl http://localhost:5000/metrics"
echo "  Test homepage:           curl http://localhost:5000/"
echo ""

# Final check
if sudo systemctl is-active --quiet blog-app && [ "$HEALTH_STATUS" = "200" ]; then
    echo "🎉 Droplet 2 setup successful! Application is running and responding."
    echo ""
    echo "✅ You can access your application at: http://$(curl -s ifconfig.me)"
else
    echo "⚠️  Setup completed but application may need attention."
    echo "   Run: sudo journalctl -u blog-app -n 50"
    echo "   Or:  sudo systemctl status blog-app"
    echo "   Logs: tail -50 /root/blog-app/logs/error.log"
fi

echo ""