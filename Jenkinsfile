pipeline {
    agent any
    
    environment {
        PYTHON_VERSION = '3.11'
        VENV_DIR = 'venv'
        DROPLET2_HOST = credentials('droplet2-host')
        DROPLET2_USER = credentials('droplet2-user')
        DROPLET2_SSH_KEY = credentials('droplet2-ssh-key')
        APP_DIR = credentials('droplet2-app-dir')
        MONGO_URI = credentials('mongo-uri')
        SECRET_KEY = credentials('secret-key')
        DATABASE_NAME = credentials('database-name')
    }
    
    stages {
        stage('Checkout') {
            steps {
                echo 'Checking out code from repository...'
                checkout scm
            }
        }
        
        stage('Setup Python Environment') {
            steps {
                echo 'Setting up Python virtual environment...'
                sh '''
                    python3 -m venv ${VENV_DIR}
                    . ${VENV_DIR}/bin/activate
                    pip install --upgrade pip
                    pip install -r requirements.txt
                '''
            }
        }
        
        stage('Check MongoDB') {
            steps {
                echo 'Verifying MongoDB is available...'
                sh '''
                    # Check if MongoDB is running locally
                    if ! pgrep -x mongod > /dev/null; then
                        echo "⚠️  MongoDB not running locally"
                        echo "Attempting to start MongoDB..."
                        
                        # Try to start with brew (macOS)
                        if command -v brew > /dev/null; then
                            brew services start mongodb-community 2>/dev/null || true
                            sleep 5
                        fi
                    fi
                    
                    # Verify MongoDB connection
                    if mongosh --eval "db.adminCommand('ping')" > /dev/null 2>&1; then
                        echo "✅ MongoDB is accessible"
                    else
                        echo "❌ MongoDB not accessible"
                        echo ""
                        echo "Please install MongoDB:"
                        echo "  brew tap mongodb/brew"
                        echo "  brew install mongodb-community"
                        echo "  brew services start mongodb-community"
                        exit 1
                    fi
                '''
            }
        }
        
        stage('Run Tests') {
            steps {
                echo 'Running pytest tests...'
                sh '''
                    . ${VENV_DIR}/bin/activate
                    export MONGO_URI=mongodb://localhost:27017/
                    export SECRET_KEY=test-secret-key-jenkins
                    pytest -v --cov=. --cov-report=xml --cov-report=html --junitxml=test-results.xml
                '''
            }
        }
        
        stage('Generate Test Reports') {
            steps {
                echo 'Publishing test results...'
                junit 'test-results.xml'
                publishHTML([
                    allowMissing: false,
                    alwaysLinkToLastBuild: true,
                    keepAll: true,
                    reportDir: 'htmlcov',
                    reportFiles: 'index.html',
                    reportName: 'Coverage Report'
                ])
            }
        }
        
        stage('Deploy to DigitalOcean Droplet 2') {
            when {
                branch 'main'
            }
            steps {
                echo 'Deploying to DigitalOcean Droplet 2...'
                script {
                    sshagent(credentials: ['droplet2-ssh-key']) {
                        sh """
                            ssh -o StrictHostKeyChecking=no ${DROPLET2_USER}@${DROPLET2_HOST} << 'ENDSSH'
set -e

# Navigate to application directory
cd ${APP_DIR}

# Pull latest code
echo "📥 Pulling latest code..."
git pull origin main

# Activate virtual environment
echo "🐍 Activating virtual environment..."
source venv/bin/activate

# Install/update dependencies
echo "📦 Installing dependencies..."
pip install -r requirements.txt

# Update environment variables
echo "⚙️  Updating environment variables..."
cat > .env << 'EOF'
SECRET_KEY=${SECRET_KEY}
MONGO_URI=${MONGO_URI}
DATABASE_NAME=${DATABASE_NAME}
FLASK_ENV=production
FLASK_DEBUG=False
EOF

# Ensure logs directory exists
mkdir -p logs

# Deactivate venv
deactivate

# Restart the application
echo "🔄 Restarting application..."
sudo systemctl restart blog-app

# Wait for app to start
echo "⏳ Waiting for application to start..."
sleep 8

# Health check with retry
for i in {1..5}; do
  if curl -f http://localhost:5000/health > /dev/null 2>&1; then
    echo "✅ Health check passed!"
    break
  else
    echo "Attempt \$i: Health check failed, waiting..."
    sleep 3
  fi
  
  if [ \$i -eq 5 ]; then
    echo "❌ Health check failed after 5 attempts"
    sudo journalctl -u blog-app -n 30
    exit 1
  fi
done

echo "🎉 Deployment successful to Droplet 2!"
ENDSSH
                        """
                    }
                }
            }
        }
    }
    
    post {
        always {
            echo 'Cleaning up...'
            sh '''
                # Clean up test database if MongoDB is local
                if mongosh --eval "db.adminCommand('ping')" > /dev/null 2>&1; then
                    mongosh --eval "db.getSiblingDB('blog_test_db').dropDatabase()" || true
                fi
                
                # Clean up virtual environment
                rm -rf ${VENV_DIR}
            '''
        }
        success {
            echo '✅ Pipeline completed successfully!'
        }
        failure {
            echo '❌ Pipeline failed!'
            echo 'Check the console output above for error details'
        }
    }
}