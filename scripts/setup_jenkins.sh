#!/bin/bash
set -e

echo "🚀 Setting up Jenkins server..."

# Update system
sudo apt-get update
sudo apt-get upgrade -y

# Install Java (required for Jenkins)
sudo apt-get install -y openjdk-17-jdk

# Add Jenkins repository
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee \
  /usr/share/keyrings/jenkins-keyring.asc > /dev/null

echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null

# Install Jenkins
sudo apt-get update
sudo apt-get install -y jenkins

# Start Jenkins
sudo systemctl enable jenkins
sudo systemctl start jenkins

# Install Docker for Jenkins to use
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins

# Install Python and dependencies for Jenkins
sudo apt-get install -y python3 python3-pip python3-venv

# Setup firewall
sudo ufw allow 22/tcp
sudo ufw allow 8080/tcp  # Jenkins
sudo ufw --force enable

# Wait for Jenkins to start
echo "⏳ Waiting for Jenkins to start..."
sleep 30

# Get initial admin password
JENKINS_PASSWORD=$(sudo cat /var/lib/jenkins/secrets/initialAdminPassword)

echo "✅ Jenkins setup complete!"
echo ""
echo "🔐 Jenkins Access Information:"
echo "  URL: http://$(curl -s ifconfig.me):8080"
echo "  Initial Admin Password: $JENKINS_PASSWORD"
echo ""
echo "📝 Next steps:"
echo "1. Access Jenkins at the URL above"
echo "2. Install suggested plugins"
echo "3. Create admin user"
echo "4. Install additional plugins:"
echo "   - SSH Agent Plugin"
echo "   - Pipeline Plugin"
echo "   - Git Plugin"
echo "   - Docker Pipeline Plugin"
echo "   - HTML Publisher Plugin"
echo "5. Configure credentials:"
echo "   - droplet2-host (Secret text)"
echo "   - droplet2-user (Secret text)"
echo "   - droplet2-ssh-key (SSH Username with private key)"
echo "   - droplet2-app-dir (Secret text)"
echo "   - mongo-uri (Secret text)"
echo "   - secret-key (Secret text)"
echo "   - database-name (Secret text)"
echo "6. Create a new Pipeline job"
echo "7. Point it to your GitHub repository"
echo "8. Use 'Jenkinsfile' as the pipeline script path"
echo ""
echo "⚠️  Important: Restart Jenkins after adding jenkins to docker group"
echo "   sudo systemctl restart jenkins"
