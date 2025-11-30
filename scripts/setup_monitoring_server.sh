#!/bin/bash
set -e

echo "🚀 Setting up Monitoring Server (Prometheus + Grafana)..."

# Update system
sudo apt-get update
sudo apt-get upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.23.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Create monitoring directory
mkdir -p ~/monitoring/{prometheus,grafana/dashboards,grafana/datasources}
cd ~/monitoring

# Create prometheus.yml
cat > prometheus/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    monitor: 'blog-app-monitor'

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
        labels:
          instance: 'prometheus-server'

  - job_name: 'blog-app-droplet1'
    scrape_interval: 10s
    static_configs:
      - targets: ['DROPLET1_IP:5000']
        labels:
          environment: 'production'
          droplet: 'droplet1'
          deployment: 'github-actions'
    metrics_path: '/metrics'

  - job_name: 'blog-app-droplet2'
    scrape_interval: 10s
    static_configs:
      - targets: ['DROPLET2_IP:5000']
        labels:
          environment: 'production'
          droplet: 'droplet2'
          deployment: 'jenkins'
    metrics_path: '/metrics'

  - job_name: 'pushgateway'
    honor_labels: true
    static_configs:
      - targets: ['pushgateway:9091']

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']

  - job_name: 'mongodb-exporter-droplet1'
    static_configs:
      - targets: ['DROPLET1_IP:9216']
        labels:
          droplet: 'droplet1'

  - job_name: 'mongodb-exporter-droplet2'
    static_configs:
      - targets: ['DROPLET2_IP:9216']
        labels:
          droplet: 'droplet2'
EOF

# Create Grafana datasource
cat > grafana/datasources/prometheus.yml << 'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
    jsonData:
      timeInterval: "15s"
EOF

# Create Grafana dashboard provisioning config
cat > grafana/dashboards/dashboard.yml << 'EOF'
apiVersion: 1

providers:
  - name: 'Blog App Dashboards'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /var/lib/grafana/dashboards
EOF

# Create docker-compose.yml
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus-data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/usr/share/prometheus/console_libraries'
      - '--web.console.templates=/usr/share/prometheus/consoles'
    restart: unless-stopped
    networks:
      - monitoring

  pushgateway:
    image: prom/pushgateway:latest
    container_name: pushgateway
    ports:
      - "9091:9091"
    restart: unless-stopped
    networks:
      - monitoring

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_INSTALL_PLUGINS=grafana-clock-panel,grafana-piechart-panel
    volumes:
      - grafana-data:/var/lib/grafana
      - ./grafana/dashboards:/etc/grafana/provisioning/dashboards
      - ./grafana/datasources:/etc/grafana/provisioning/datasources
    restart: unless-stopped
    networks:
      - monitoring
    depends_on:
      - prometheus

  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    ports:
      - "9100:9100"
    restart: unless-stopped
    networks:
      - monitoring
    command:
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro

networks:
  monitoring:
    driver: bridge

volumes:
  prometheus-data:
  grafana-data:
EOF

# Setup firewall
sudo ufw allow 22/tcp
sudo ufw allow 9090/tcp  # Prometheus
sudo ufw allow 9091/tcp  # Pushgateway
sudo ufw allow 3000/tcp  # Grafana
sudo ufw --force enable

# Start services
docker-compose up -d

echo "✅ Monitoring server setup complete!"
echo ""
echo "📊 Access URLs:"
echo "  Prometheus: http://$(curl -s ifconfig.me):9090"
echo "  Grafana: http://$(curl -s ifconfig.me):3000"
echo "  Pushgateway: http://$(curl -s ifconfig.me):9091"
echo ""
echo "🔐 Default Grafana credentials:"
echo "  Username: admin"
echo "  Password: admin"
echo ""
echo "📝 Next steps:"
echo "1. Update prometheus.yml with actual Droplet IPs"
echo "2. Restart Prometheus: docker-compose restart prometheus"
echo "3. Log into Grafana and change the admin password"
echo "4. Import dashboard from grafana_dashboard.json"
echo "5. Allow Droplet IPs in firewall if needed"
