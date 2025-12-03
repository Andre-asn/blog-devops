pipeline {
    agent any
    
    environment {
        // Python configuration
        PYTHON_VERSION = '3.11'
        VENV_DIR = 'venv'
        
        // Droplet 2 credentials
        DROPLET2_HOST = credentials('droplet2-host')
        DROPLET2_USER = credentials('droplet2-user')
        DROPLET2_SSH_KEY = credentials('droplet2-ssh-key')
        APP_DIR = credentials('droplet2-app-dir')
        
        // Application configuration
        MONGO_URI = credentials('mongo-uri')
        SECRET_KEY = credentials('secret-key')
        DATABASE_NAME = credentials('database-name')
        
        // Add Homebrew paths for MongoDB (macOS)
        PATH = "/opt/homebrew/bin:/usr/local/bin:${env.PATH}"
    }
    
    stages {
        stage('Checkout') {
            steps {
                echo '📥 Checking out code from repository...'
                checkout scm
            }
        }
        
        stage('Setup Python Environment') {
            steps {
                echo '🐍 Setting up Python virtual environment...'
                sh '''
                    # Create virtual environment
                    python3 -m venv ${VENV_DIR}
                    
                    # Activate virtual environment
                    . ${VENV_DIR}/bin/activate
                    
                    # Upgrade pip
                    pip install --upgrade pip
                    
                    # Install dependencies
                    pip install -r requirements.txt
                    
                    # Verify critical packages
                    echo "Installed packages:"
                    pip list | grep -E "Flask|pymongo|pytest|gunicorn|prometheus"
                '''
            }
        }
        
        stage('Check MongoDB') {
            steps {
                echo '🍃 Verifying MongoDB is available...'
                sh '''
                    # Add Homebrew paths explicitly
                    export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
                    
                    echo "=== MongoDB Detection ==="
                    
                    # Check for mongosh
                    if command -v mongosh > /dev/null 2>&1; then
                        echo "✅ mongosh found: $(which mongosh)"
                    else
                        echo "⚠️  mongosh not found in PATH"
                    fi
                    
                    # Check for mongod
                    if command -v mongod > /dev/null 2>&1; then
                        echo "✅ mongod found: $(which mongod)"
                    else
                        echo "⚠️  mongod not found in PATH"
                    fi
                    
                    echo ""
                    echo "=== MongoDB Status ==="
                    
                    # Check if MongoDB is running
                    if pgrep -x mongod > /dev/null; then
                        echo "✅ MongoDB process is running"
                        echo "   PID: $(pgrep -x mongod)"
                    else
                        echo "⚠️  MongoDB process not detected"
                        echo "   Attempting to start MongoDB..."
                        
                        # Try to start with brew
                        if command -v brew > /dev/null; then
                            brew services start mongodb-community 2>&1 || true
                            sleep 5
                        else
                            echo "❌ Homebrew not found, cannot auto-start MongoDB"
                        fi
                    fi
                    
                    echo ""
                    echo "=== MongoDB Connection Test ==="
                    
                    # Try to connect with mongosh (try both common paths)
                    CONNECTION_SUCCESS=false
                    
                    if /opt/homebrew/bin/mongosh --eval "db.adminCommand('ping')" > /dev/null 2>&1; then
                        echo "✅ MongoDB connection successful via /opt/homebrew/bin/mongosh"
                        CONNECTION_SUCCESS=true
                    elif /usr/local/bin/mongosh --eval "db.adminCommand('ping')" > /dev/null 2>&1; then
                        echo "✅ MongoDB connection successful via /usr/local/bin/mongosh"
                        CONNECTION_SUCCESS=true
                    elif mongosh --eval "db.adminCommand('ping')" > /dev/null 2>&1; then
                        echo "✅ MongoDB connection successful via mongosh (in PATH)"
                        CONNECTION_SUCCESS=true
                    else
                        CONNECTION_SUCCESS=false
                    fi
                    
                    if [ "$CONNECTION_SUCCESS" = false ]; then
                        echo "❌ MongoDB connection failed"
                        echo ""
                        echo "=== Troubleshooting Information ==="
                        echo "Current PATH: $PATH"
                        echo ""
                        echo "Please ensure MongoDB is installed and running:"
                        echo "  1. Install: brew tap mongodb/brew && brew install mongodb-community"
                        echo "  2. Start:   brew services start mongodb-community"
                        echo "  3. Verify:  mongosh --eval \\"db.adminCommand('ping')\\""
                        echo ""
                        exit 1
                    fi
                    
                    echo ""
                    echo "✅ MongoDB is ready for testing"
                '''
            }
        }
        
        stage('Run Tests') {
            steps {
                echo '🧪 Running pytest tests...'
                sh '''
                    # Ensure Homebrew paths are available
                    export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
                    
                    # Activate virtual environment
                    . ${VENV_DIR}/bin/activate
                    
                    # Set test environment variables
                    export MONGO_URI=mongodb://localhost:27017/
                    export SECRET_KEY=test-secret-key-jenkins-build-${BUILD_NUMBER}
                    export FLASK_ENV=testing
                    
                    # Run pytest with coverage
                    echo "Running tests..."
                    pytest -v \
                        --cov=. \
                        --cov-report=xml \
                        --cov-report=html \
                        --cov-report=term \
                        --junitxml=test-results.xml \
                        --tb=short
                    
                    # Show summary
                    echo ""
                    echo "=== Test Summary ==="
                    if [ -f test-results.xml ]; then
                        echo "✅ Test results generated: test-results.xml"
                    fi
                    if [ -f coverage.xml ]; then
                        echo "✅ Coverage report generated: coverage.xml"
                    fi
                    if [ -d htmlcov ]; then
                        echo "✅ HTML coverage report: htmlcov/index.html"
                    fi
                '''
            }
        }
        
        stage('Generate Test Reports') {
            steps {
                echo '📊 Publishing test results and coverage reports...'
                
                // Publish JUnit test results
                junit testResults: 'test-results.xml', allowEmptyResults: false
                
                // Publish HTML coverage report
                publishHTML([
                    allowMissing: false,
                    alwaysLinkToLastBuild: true,
                    keepAll: true,
                    reportDir: 'htmlcov',
                    reportFiles: 'index.html',
                    reportName: 'Coverage Report',
                    reportTitles: 'Code Coverage'
                ])
                
                echo '✅ Test reports published successfully'
            }
        }
        
        stage('Deploy to DigitalOcean Droplet 2') {
            steps {
                echo '🚀 Deploying to DigitalOcean Droplet 2...'
                echo "Branch: ${env.GIT_BRANCH}"
                echo "Build Number: ${env.BUILD_NUMBER}"
                
                script {
                    sshagent(credentials: ['droplet2-ssh-key']) {
                        sh """
                            echo "Connecting to ${DROPLET2_HOST}..."
                            
                            ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 ${DROPLET2_USER}@${DROPLET2_HOST} 'bash -s' <<'ENDSSH'
                            set -e

                            echo "=== Starting Deployment ==="
                            echo "Build Number: ${BUILD_NUMBER}"
                            echo "Timestamp: \$(date)"
                            echo ""

                            # Navigate to application directory
                            cd ${APP_DIR}
                            echo "✅ In directory: \$(pwd)"

                            # Check current branch
                            echo "Current branch: \$(git branch --show-current)"

                            # Stash any local changes
                            git stash 2>/dev/null || true

                            # Pull latest code
                            echo ""
                            echo "📥 Pulling latest code from main branch..."
                            git fetch origin
                            git checkout main
                            git pull origin main

                            # Show latest commit
                            echo "Latest commit: \$(git log -1 --oneline)"

                            # Activate virtual environment
                            echo ""
                            echo "🐍 Activating virtual environment..."
                            if [ ! -d "venv" ]; then
                                echo "⚠️  Virtual environment not found, creating..."
                                python3 -m venv venv
                            fi
                            source venv/bin/activate

                            # Verify activation
                            echo "Python: \$(which python3)"
                            echo "Pip: \$(which pip)"

                            # Install/update dependencies
                            echo ""
                            echo "📦 Installing dependencies..."
                            pip install --upgrade pip
                            pip install -r requirements.txt

                            # Verify critical packages
                            echo "Verifying packages:"
                            pip show Flask pymongo gunicorn prometheus-client | grep -E "Name|Version" || true

                            # Update environment variables using echo statements
                            echo ""
                            echo "⚙️  Updating environment variables..."
                            echo "SECRET_KEY=${SECRET_KEY}" > .env
                            echo "MONGO_URI=${MONGO_URI}" >> .env
                            echo "DATABASE_NAME=${DATABASE_NAME}" >> .env
                            echo "FLASK_ENV=production" >> .env
                            echo "FLASK_DEBUG=False" >> .env
                            chmod 600 .env
                            echo "✅ Environment file updated"

                            # Ensure logs directory exists with correct permissions
                            echo ""
                            echo "📝 Setting up logs directory..."
                            mkdir -p logs
                            chmod 755 logs
                            echo "✅ Logs directory ready"

                            # Deactivate virtual environment
                            deactivate

                            # Check application configuration
                            echo ""
                            echo "🔍 Pre-deployment checks..."

                            # Check if systemd service exists
                            if ! systemctl list-unit-files | grep -q "blog-app.service"; then
                                echo "❌ blog-app.service not found"
                                echo "Please run the setup script first"
                                exit 1
                            fi
                            echo "✅ Service file exists"

                            # Check MongoDB
                            if ! systemctl is-active --quiet mongod; then
                                echo "⚠️  MongoDB not running, attempting to start..."
                                sudo systemctl start mongod
                                sleep 3
                            fi
                            echo "✅ MongoDB is running"

                            # Restart the application
                            echo ""
                            echo "🔄 Restarting application..."
                            sudo systemctl restart blog-app

                            # Wait for application to start
                            echo "⏳ Waiting for application to start (10 seconds)..."
                            sleep 10

                            # Check if service started successfully
                            if ! sudo systemctl is-active --quiet blog-app; then
                                echo "❌ Application failed to start"
                                echo ""
                                echo "=== Service Status ==="
                                sudo systemctl status blog-app --no-pager -l || true
                                echo ""
                                echo "=== Recent Logs ==="
                                sudo journalctl -u blog-app -n 20 --no-pager || true
                                exit 1
                            fi

                            echo "✅ Application service is running"

                            # Health check with retry logic
                            echo ""
                            echo "🏥 Performing health checks..."
                            HEALTH_CHECK_PASSED=false

                            for i in 1 2 3 4 5; do
                                echo "Attempt \$i/5..."
                                
                                # Test health endpoint
                                if curl -f -s http://localhost:5000/health > /dev/null 2>&1; then
                                    echo "✅ Health endpoint responding"
                                    HEALTH_CHECK_PASSED=true
                                    break
                                else
                                    if [ \$i -lt 5 ]; then
                                        echo "⚠️  Health check failed, retrying in 3 seconds..."
                                        sleep 3
                                    fi
                                fi
                            done

                            if [ "\$HEALTH_CHECK_PASSED" = false ]; then
                                echo "❌ Health check failed after 5 attempts"
                                echo ""
                                echo "=== Application Logs ==="
                                sudo journalctl -u blog-app -n 30 --no-pager
                                echo ""
                                echo "=== Error Logs ==="
                                tail -20 logs/error.log 2>/dev/null || echo "No error log found"
                                exit 1
                            fi

                            # Test metrics endpoint
                            echo ""
                            echo "Testing metrics endpoint..."
                            if curl -f -s http://localhost:5000/metrics | grep -q "blog_"; then
                                echo "✅ Metrics endpoint responding"
                            else
                                echo "⚠️  Metrics endpoint may have issues (non-critical)"
                            fi

                            # Test main page
                            echo ""
                            echo "Testing main application..."
                            if curl -f -s http://localhost:5000/ | grep -q "<!DOCTYPE html>"; then
                                echo "✅ Main page responding"
                            else
                                echo "⚠️  Main page may have issues"
                            fi

                            # Show deployment summary
                            echo ""
                            echo "=== Deployment Summary ==="
                            echo "✅ Code updated to latest commit"
                            echo "✅ Dependencies installed"
                            echo "✅ Environment configured"
                            echo "✅ Application restarted"
                            echo "✅ Health checks passed"
                            echo ""
                            echo "🎉 Deployment successful to Droplet 2!"
                            echo "Timestamp: \$(date)"
                            ENDSSH
                        """
                    }
                }
            }
        }
    }
    
    post {
        always {
            echo '🧹 Cleaning up...'
            sh '''
                # Add Homebrew paths for MongoDB access
                export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
                
                # Clean up test database
                echo "Cleaning test database..."
                /opt/homebrew/bin/mongosh --eval "db.getSiblingDB('blog_test_db').dropDatabase()" 2>/dev/null || \
                /usr/local/bin/mongosh --eval "db.getSiblingDB('blog_test_db').dropDatabase()" 2>/dev/null || \
                mongosh --eval "db.getSiblingDB('blog_test_db').dropDatabase()" 2>/dev/null || \
                echo "⚠️  Could not clean test database (non-critical)"
                
                # Clean up virtual environment
                echo "Removing virtual environment..."
                rm -rf ${VENV_DIR}
                
                echo "✅ Cleanup complete"
            '''
        }
        success {
            echo '✅ Pipeline completed successfully!'
            echo "Build #${BUILD_NUMBER} - SUCCESS"
            echo "Deployed to Droplet 2 at ${DROPLET2_HOST}"
        }
        failure {
            echo '❌ Pipeline failed!'
            echo "Build #${BUILD_NUMBER} - FAILURE"
            echo 'Please check the console output above for error details'
            echo ''
            echo 'Common issues:'
            echo '  - MongoDB not running: brew services start mongodb-community'
            echo '  - Tests failing: Check test output in "Run Tests" stage'
            echo '  - Deployment failing: Check SSH connection and credentials'
        }
        unstable {
            echo '⚠️  Pipeline completed with warnings'
            echo 'Some tests may have failed or coverage is low'
        }
    }
}