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
        
        stage('Start MongoDB') {
            steps {
                echo 'Starting MongoDB container for testing...'
                sh '''
                    docker run -d \
                        --name mongodb-test-${BUILD_NUMBER} \
                        -p 27017:27017 \
                        mongo:7.0
                    
                    # Wait for MongoDB to be ready
                    sleep 10
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
                    def remote = [:]
                    remote.name = 'droplet2'
                    remote.host = "${DROPLET2_HOST}"
                    remote.user = "${DROPLET2_USER}"
                    remote.identityFile = "${DROPLET2_SSH_KEY}"
                    remote.allowAnyHosts = true
                    
                    sshCommand remote: remote, command: """
                        set -e
                        cd ${APP_DIR}
                        
                        # Pull latest code
                        git pull origin main
                        
                        # Activate virtual environment
                        source venv/bin/activate
                        
                        # Install/update dependencies
                        pip install -r requirements.txt
                        
                        # Update environment variables
                        cat > .env << 'EOF'
SECRET_KEY=${SECRET_KEY}
MONGO_URI=${MONGO_URI}
DATABASE_NAME=${DATABASE_NAME}
FLASK_ENV=production
FLASK_DEBUG=False
EOF
                        
                        # Restart the application
                        sudo systemctl restart blog-app
                        
                        # Wait for app to start
                        sleep 5
                        
                        # Health check
                        curl -f http://localhost:5000/ || exit 1
                        
                        echo 'Deployment successful to Droplet 2!'
                    """
                }
            }
        }
        
        stage('Update Prometheus Metrics') {
            when {
                branch 'main'
            }
            steps {
                echo 'Updating Prometheus metrics endpoint...'
                sh '''
                    # Push deployment metrics to Pushgateway
                    cat <<EOF | curl --data-binary @- http://prometheus-server:9091/metrics/job/blog-app/instance/droplet2
# TYPE deployment_info gauge
deployment_info{version="${BUILD_NUMBER}",environment="production",droplet="droplet2"} 1
# TYPE deployment_timestamp gauge
deployment_timestamp $(date +%s)
EOF
                '''
            }
        }
    }
    
    post {
        always {
            echo 'Cleaning up...'
            sh '''
                # Stop and remove MongoDB test container
                docker stop mongodb-test-${BUILD_NUMBER} || true
                docker rm mongodb-test-${BUILD_NUMBER} || true
                
                # Clean up virtual environment
                rm -rf ${VENV_DIR}
            '''
        }
        success {
            echo '✅ Pipeline completed successfully!'
            emailext(
                subject: "Jenkins Build Success: ${env.JOB_NAME} - ${env.BUILD_NUMBER}",
                body: "The build and deployment completed successfully.\nBuild URL: ${env.BUILD_URL}",
                to: "${env.CHANGE_AUTHOR_EMAIL}"
            )
        }
        failure {
            echo '❌ Pipeline failed!'
            emailext(
                subject: "Jenkins Build Failed: ${env.JOB_NAME} - ${env.BUILD_NUMBER}",
                body: "The build or deployment failed.\nBuild URL: ${env.BUILD_URL}",
                to: "${env.CHANGE_AUTHOR_EMAIL}"
            )
        }
    }
}
