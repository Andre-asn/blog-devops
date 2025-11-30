#!/bin/bash
set -e

echo "🚀 Setting up DigitalOcean Droplet 2 for Jenkins deployment..."

# Update system
sudo apt-get update
sudo apt-get upgrade -y

# Install required packages
sudo apt-get install -y python3 python3-pip python3-venv git nginx curl

# Install MongoDB
curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | sudo gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list
sudo apt-get update
sudo apt-get install -y mongodb-org
sudo systemctl start mongod
sudo systemctl enable mongod

# Create application directory
sudo mkdir -p /var/www/blog-app
sudo chown -R $USER:$USER /var/www/blog-app

# Clone repository
cd /var/www/blog-app
git clone YOUR_REPO_URL .

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install --upgrade pip
pip install -r requirements.txt

# Create .env file
cat > .env << 'EOF'
SECRET_KEY=your-secret-key-here-different-from-droplet1
MONGO_URI=mongodb://localhost:27017/
DATABASE_NAME=blog_db
FLASK_ENV=production
FLASK_DEBUG=False
EOF

# Create log directory
sudo mkdir -p /var/log/blog-app
sudo chown -R www-data:www-data /var/log/blog-app

# Install systemd service
sudo cp blog-app.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable blog-app
sudo systemctl start blog-app

# Configure Nginx (same as Droplet 1)
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
sudo nginx -t
sudo systemctl restart nginx

# Setup firewall
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 5000/tcp
sudo ufw --force enable

# Install MongoDB exporter
wget https://github.com/percona/mongodb_exporter/releases/download/v0.40.0/mongodb_exporter-0.40.0.linux-amd64.tar.gz
tar xvzf mongodb_exporter-0.40.0.linux-amd64.tar.gz
sudo mv mongodb_exporter /usr/local/bin/
rm mongodb_exporter-0.40.0.linux-amd64.tar.gz

# Create MongoDB exporter service
sudo tee /etc/systemd/system/mongodb-exporter.service > /dev/null << 'EOF'
[Unit]
Description=MongoDB Exporter
After=network.target

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

echo "✅ Droplet 2 setup complete!"
echo "📝 Next steps:"
echo "1. Update .env file with actual values"
echo "2. Add SSH credentials to Jenkins"
echo "3. Configure Jenkins credentials:"
echo "   - droplet2-host: This droplet's IP"
echo "   - droplet2-user: SSH username"
echo "   - droplet2-ssh-key: Private SSH key"
echo "   - droplet2-app-dir: /var/www/blog-app"
echo "   - mongo-uri, secret-key, database-name"
echo "4. Update monitoring/prometheus.yml with this droplet's IP"
