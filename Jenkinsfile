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
        
        // GitHub credentials for pushing documentation
        GITHUB_TOKEN = credentials('github-token')
        GITHUB_REPO = 'Andre-asn/blog-devops'
        
        // Add Homebrew paths for MongoDB (macOS)
        PATH = "/opt/homebrew/bin:/usr/local/bin:${env.PATH}"
        
        // Documentation directory
        DOC_DIR = 'docs/jenkins-doc'
        
        // Artifact configuration
        ARTIFACT_DIR = 'artifacts/jenkins'
        VERSION_MAJOR = '1'
        VERSION_MINOR = '0'
        
        // Retry configuration
        MAX_RETRIES = '5'
        RETRY_DELAY = '10'
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
                    
                    # Install Pylint (includes Pyreverse)
                    pip install pylint
                    
                    # Verify critical packages
                    echo "Installed packages:"
                    pip list | grep -E "Flask|pymongo|pytest|gunicorn|prometheus|pylint"
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
        
        stage('Sync with Remote Before Documentation') {
            steps {
                echo '🔄 Syncing with remote repository before documentation generation...'
                sh '''
                    echo "=== Pulling Latest Changes from Remote ==="
                    
                    # Configure git
                    git config user.email "jenkins@ci.local"
                    git config user.name "Jenkins CI"
                    
                    # Fetch latest
                    echo "Fetching from origin..."
                    git fetch origin main
                    
                    # Check current status
                    LOCAL_COMMIT=$(git rev-parse HEAD)
                    REMOTE_COMMIT=$(git rev-parse origin/main)
                    
                    echo "Local commit:  $LOCAL_COMMIT"
                    echo "Remote commit: $REMOTE_COMMIT"
                    
                    # Pull if behind
                    if [ "$LOCAL_COMMIT" != "$REMOTE_COMMIT" ]; then
                        BEHIND=$(git rev-list HEAD..origin/main --count)
                        echo "⚠️  Local is $BEHIND commit(s) behind remote"
                        echo "Pulling latest changes..."
                        
                        git pull origin main --rebase --autostash || {
                            echo "⚠️  Pull had issues, attempting to resolve..."
                            git rebase --abort 2>/dev/null || true
                            git reset --hard origin/main
                        }
                        
                        echo "✅ Successfully synced with remote"
                    else
                        echo "✅ Already up to date"
                    fi
                    
                    echo "Final commit: $(git rev-parse HEAD)"
                '''
            }
        }
        
        stage('Generate Pyreverse Documentation') {
            steps {
                echo '📚 Generating Pyreverse UML documentation...'
                sh '''
                    # Activate virtual environment
                    . ${VENV_DIR}/bin/activate
                    
                    # Create documentation directory
                    mkdir -p ${DOC_DIR}
                    
                    # Find all Python files (excluding venv, tests, and __pycache__)
                    echo "=== Finding Python files ==="
                    PYTHON_FILES=$(find . -name "*.py" \
                        -not -path "./venv/*" \
                        -not -path "./.venv/*" \
                        -not -path "./${VENV_DIR}/*" \
                        -not -path "./__pycache__/*" \
                        -not -path "./tests/*" \
                        -not -path "./test_*" \
                        -not -path "./.git/*" \
                        -not -path "./htmlcov/*" \
                        -not -name "conftest.py" \
                        -not -name "test_*.py" \
                        | tr '\\n' ' ')
                    
                    echo "Python files found:"
                    echo "$PYTHON_FILES" | tr ' ' '\\n' | grep -v "^$" | sed 's/^/  • /'
                    echo ""
                    
                    if [ -z "$PYTHON_FILES" ]; then
                        echo "⚠️  No Python files found to analyze"
                        exit 0
                    fi
                    
                    # Check if Graphviz is installed
                    echo "=== Checking Graphviz ==="
                    if command -v dot > /dev/null 2>&1; then
                        echo "✅ Graphviz is installed: $(dot -V 2>&1)"
                        GRAPHVIZ_AVAILABLE=true
                    else
                        echo "⚠️  Graphviz (dot) not found - will generate .dot files only"
                        echo "   Install with: brew install graphviz"
                        GRAPHVIZ_AVAILABLE=false
                    fi
                    echo ""
                    
                    # Generate UML diagrams with Pyreverse
                    echo "=== Running Pyreverse ==="
                    
                    # Generate class diagrams
                    echo "Generating class diagrams..."
                    pyreverse -o dot -p blog_app $PYTHON_FILES -d ${DOC_DIR} 2>/dev/null || true
                    
                    # List generated .dot files
                    echo ""
                    echo "Generated .dot files:"
                    ls -la ${DOC_DIR}/*.dot 2>/dev/null | sed 's/^/  /' || echo "  No .dot files generated"
                    echo ""
                    
                    # Convert .dot files to PNG and SVG if Graphviz is available
                    if [ "$GRAPHVIZ_AVAILABLE" = true ]; then
                        echo "=== Converting to PNG and SVG ==="
                        
                        for dotfile in ${DOC_DIR}/*.dot; do
                            if [ -f "$dotfile" ]; then
                                basename=$(basename "$dotfile" .dot)
                                echo "Converting $basename..."
                                
                                # Generate PNG
                                dot -Tpng "$dotfile" -o "${DOC_DIR}/${basename}.png" 2>/dev/null && \
                                    echo "  ✅ ${basename}.png" || echo "  ⚠️  Failed to generate ${basename}.png"
                                
                                # Generate SVG
                                dot -Tsvg "$dotfile" -o "${DOC_DIR}/${basename}.svg" 2>/dev/null && \
                                    echo "  ✅ ${basename}.svg" || echo "  ⚠️  Failed to generate ${basename}.svg"
                            fi
                        done
                        echo ""
                    fi
                    
                    # Generate README for the documentation
                    echo "=== Generating Documentation README ==="
                    cat > ${DOC_DIR}/README.md << 'DOCREADME'
# Jenkins Pipeline - Code Documentation

This documentation is automatically generated by the Jenkins CI/CD pipeline using Pyreverse.

## Generated Files

### UML Diagrams

| File | Description |
|------|-------------|
| classes_blog_app.dot | Class diagram in DOT format |
| classes_blog_app.png | Class diagram as PNG image |
| classes_blog_app.svg | Class diagram as SVG (scalable) |
| packages_blog_app.dot | Package diagram in DOT format |
| packages_blog_app.png | Package diagram as PNG image |
| packages_blog_app.svg | Package diagram as SVG (scalable) |

### Class Diagram
Shows the classes in the application, their attributes, methods, and relationships.

![Class Diagram](classes_blog_app.png)

### Package Diagram
Shows the package/module structure and dependencies.

![Package Diagram](packages_blog_app.png)

## Generation Details

- **Generated by**: Jenkins Pipeline
- **Tool**: Pyreverse (part of Pylint)
- **Visualization**: Graphviz

## How to Regenerate

These diagrams are automatically regenerated on each successful Jenkins pipeline run.

To manually regenerate:

1. Install dependencies: pip install pylint
2. Install Graphviz: brew install graphviz
3. Generate dot files: pyreverse -o dot -p blog_app *.py
4. Convert to images: dot -Tpng classes_blog_app.dot -o classes_blog_app.png

## Last Updated

DOCREADME
                    
                    # Add timestamp to README
                    echo "**Timestamp**: $(date)" >> ${DOC_DIR}/README.md
                    echo "" >> ${DOC_DIR}/README.md
                    echo "**Build Number**: ${BUILD_NUMBER}" >> ${DOC_DIR}/README.md
                    
                    # Show final documentation directory contents
                    echo "=== Documentation Generated ==="
                    echo "Contents of ${DOC_DIR}:"
                    ls -la ${DOC_DIR}/ | sed 's/^/  /'
                    echo ""
                    echo "✅ Pyreverse documentation generated successfully"
                '''
            }
        }
        
        stage('Install LaTeX Dependencies') {
            steps {
                echo '📦 Installing LaTeX packages...'
                sh '''
                    # Check if LaTeX is already installed
                    if command -v pdflatex > /dev/null 2>&1; then
                        echo "✅ LaTeX already installed: $(pdflatex --version | head -1)"
                    else
                        echo "Installing BasicTeX (lightweight LaTeX distribution)..."
                        brew install --cask basictex || {
                            echo "⚠️  BasicTeX installation failed, trying MacTeX..."
                            brew install --cask mactex-no-gui || {
                                echo "❌ Failed to install LaTeX"
                                exit 1
                            }
                        }
                        
                        # Add TeX binaries to PATH
                        export PATH="/usr/local/texlive/2023basic/bin/universal-darwin:$PATH"
                        export PATH="/Library/TeX/texbin:$PATH"
                        
                        # Verify installation
                        if command -v pdflatex > /dev/null 2>&1; then
                            echo "✅ LaTeX installed successfully"
                            pdflatex --version | head -1
                        else
                            echo "❌ LaTeX installation verification failed"
                            exit 1
                        fi
                    fi
                '''
            }
        }
        
        stage('Update LaTeX Documentation') {
            steps {
                echo '📝 Updating LaTeX master documentation...'
                sh '''
                    echo "=== Updating LaTeX Documentation ==="
                    echo "Current HEAD: $(git rev-parse HEAD)"
                    echo "Current commit short: $(git rev-parse --short=7 HEAD)"
                    echo ""
                    
                    # Check if template exists
                    if [ ! -f "documentation/master_documentation.tex" ]; then
                        echo "❌ Template file not found!"
                        exit 1
                    fi
                    
                    # Show current commit hash in template (before update)
                    echo "Commit hash in template (before):"
                    grep -m 1 "newcommand{\\\COMMITHASH}" documentation/master_documentation.tex || echo "Not found"
                    echo ""
                    
                    chmod +x scripts/update_latex_documentation.sh
                    ./scripts/update_latex_documentation.sh
                    
                    echo ""
                    echo "=== Verification ==="
                    # Verify the file was updated with the correct commit hash
                    EXPECTED_HASH=$(git rev-parse --short=7 HEAD)
                    ACTUAL_HASH=$(grep -m 1 "newcommand{\\\COMMITHASH}" documentation/master_documentation.tex | sed 's/.*{\([^}]*\)}.*/\1/')
                    
                    echo "Expected commit hash: ${EXPECTED_HASH}"
                    echo "Actual commit hash in file: ${ACTUAL_HASH}"
                    
                    if [ "${EXPECTED_HASH}" != "${ACTUAL_HASH}" ]; then
                        echo "❌ ERROR: Commit hash mismatch! File was not updated correctly."
                        echo "   Expected: ${EXPECTED_HASH}"
                        echo "   Found: ${ACTUAL_HASH}"
                        exit 1
                    fi
                    
                    echo "✅ LaTeX file updated successfully with commit ${EXPECTED_HASH}"
                    
                    # Show file modification time
                    echo "File modification time:"
                    ls -lh documentation/master_documentation.tex
                '''
            }
        }
        
        stage('Compile LaTeX to PDF') {
            steps {
                echo '📄 Compiling LaTeX document to PDF...'
                sh '''
                    # Add TeX binaries to PATH
                    export PATH="/usr/local/texlive/2023basic/bin/universal-darwin:$PATH"
                    export PATH="/Library/TeX/texbin:$PATH"
                    
                    echo "📄 Compiling LaTeX document..."
                    cd documentation
                    
                    # Run pdflatex multiple times for TOC and references
                    pdflatex -interaction=nonstopmode -halt-on-error master_documentation.tex || {
                        echo "⚠️  First compilation had warnings/errors, checking output..."
                        if [ -f master_documentation.pdf ]; then
                            echo "✅ PDF was generated despite warnings"
                        else
                            echo "❌ PDF generation failed"
                            if [ -f master_documentation.log ]; then
                                cat master_documentation.log | tail -50
                            fi
                            exit 1
                        fi
                    }
                    
                    # Second pass for TOC
                    pdflatex -interaction=nonstopmode -halt-on-error master_documentation.tex || true
                    
                    # Third pass to ensure all references are resolved
                    pdflatex -interaction=nonstopmode master_documentation.tex || true
                    
                    if [ -f master_documentation.pdf ]; then
                        echo "✅ PDF generated successfully"
                        ls -lh master_documentation.pdf
                        echo ""
                        echo "PDF size: $(du -h master_documentation.pdf | cut -f1)"
                    else
                        echo "❌ PDF generation failed"
                        if [ -f master_documentation.log ]; then
                            echo "LaTeX log file:"
                            cat master_documentation.log | tail -100
                        fi
                        exit 1
                    fi
                '''
            }
        }
        
        stage('Generate Deployment Artifact') {
            steps {
                echo '📦 Generating deployment-ready artifact with semantic versioning...'
                sh '''
                    echo "=== Generating Deployment Artifact ==="
                    
                    # Get truncated commit hash (7 characters)
                    COMMIT_HASH=$(git rev-parse --short=7 HEAD)
                    VERSION="${VERSION_MAJOR}.${VERSION_MINOR}.${BUILD_NUMBER}"
                    ARTIFACT_NAME="blog-app-${COMMIT_HASH}"
                    ARTIFACT_FILE="${ARTIFACT_NAME}.zip"
                    
                    echo "Version: ${VERSION}"
                    echo "Commit Hash: ${COMMIT_HASH}"
                    echo "Artifact Name: ${ARTIFACT_NAME}"
                    echo ""
                    
                    # Create artifact directory
                    mkdir -p ${ARTIFACT_DIR}
                    
                    # Create a temporary directory for artifact contents
                    TEMP_ARTIFACT_DIR=$(mktemp -d)
                    echo "Temporary directory: ${TEMP_ARTIFACT_DIR}"
                    
                    # Copy application files (excluding unnecessary files)
                    echo ""
                    echo "=== Collecting Application Files ==="
                    
                    # Copy Python files
                    echo "Copying Python source files..."
                    find . -name "*.py" \
                        -not -path "./venv/*" \
                        -not -path "./.venv/*" \
                        -not -path "./${VENV_DIR}/*" \
                        -not -path "./__pycache__/*" \
                        -not -path "./.git/*" \
                        -not -path "./htmlcov/*" \
                        -not -path "./artifacts/*" \
                        -exec cp --parents {} ${TEMP_ARTIFACT_DIR}/ \\;
                    
                    # Copy templates
                    if [ -d "templates" ]; then
                        echo "Copying templates..."
                        cp -r templates ${TEMP_ARTIFACT_DIR}/
                    fi
                    
                    # Copy static files
                    if [ -d "static" ]; then
                        echo "Copying static files..."
                        cp -r static ${TEMP_ARTIFACT_DIR}/
                    fi
                    
                    # Copy requirements
                    if [ -f "requirements.txt" ]; then
                        echo "Copying requirements.txt..."
                        cp requirements.txt ${TEMP_ARTIFACT_DIR}/
                    fi
                    
                    # Copy configuration files
                    for config_file in .pylintrc pytest.ini setup.py setup.cfg pyproject.toml; do
                        if [ -f "$config_file" ]; then
                            echo "Copying $config_file..."
                            cp "$config_file" ${TEMP_ARTIFACT_DIR}/
                        fi
                    done
                    
                    # Generate VERSION file
                    echo "Generating VERSION file..."
                    cat > ${TEMP_ARTIFACT_DIR}/VERSION << VERSIONEOF
{
    "version": "${VERSION}",
    "major": ${VERSION_MAJOR},
    "minor": ${VERSION_MINOR},
    "build": ${BUILD_NUMBER},
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "git_commit": "$(git rev-parse HEAD)",
    "git_branch": "$(git rev-parse --abbrev-ref HEAD)",
    "built_by": "Jenkins CI",
    "pipeline": "blog-app-pipeline"
}
VERSIONEOF
                    
                    # Generate MANIFEST file
                    echo "Generating MANIFEST file..."
                    cat > ${TEMP_ARTIFACT_DIR}/MANIFEST << MANIFESTEOF
Blog Application Deployment Artifact
=====================================

Version: ${VERSION}
Build Number: ${BUILD_NUMBER}
Build Date: $(date)
Git Commit: $(git rev-parse HEAD)
Git Branch: $(git rev-parse --abbrev-ref HEAD)

Contents:
---------
MANIFESTEOF
                    
                    # List contents for manifest
                    (cd ${TEMP_ARTIFACT_DIR} && find . -type f | sort | sed 's/^/  /') >> ${TEMP_ARTIFACT_DIR}/MANIFEST
                    
                    # Create the ZIP artifact
                    echo ""
                    echo "=== Creating ZIP Artifact ==="
                    (cd ${TEMP_ARTIFACT_DIR} && zip -r ${ARTIFACT_FILE} .)
                    
                    # Move artifact to artifact directory
                    mv ${TEMP_ARTIFACT_DIR}/${ARTIFACT_FILE} ${ARTIFACT_DIR}/
                    
                    # Clean up temp directory
                    rm -rf ${TEMP_ARTIFACT_DIR}
                    
                    # Generate artifact README
                    echo "Generating artifact README..."
                    cat > ${ARTIFACT_DIR}/README.md << 'ARTIFACTREADME'
# Jenkins Pipeline - Deployment Artifacts

This directory contains deployment-ready artifacts generated by the Jenkins CI/CD pipeline.

## Versioning Scheme

Artifacts are named using the commit hash: `blog-app-<commit-hash>`

- **Commit Hash**: Truncated 7-character Git commit hash (e.g., `feb3464`)
- The VERSION file inside the artifact still contains semantic versioning (`major.minor.changelist`)
- This allows easy identification of which commit the artifact represents

## Artifact Contents

The ZIP artifact contains:

- Python source files (*.py)
- Templates (templates/)
- Static files (static/)
- Requirements (requirements.txt)
- Configuration files
- VERSION file (JSON metadata)
- MANIFEST file (contents listing)

## How to Deploy

1. Download the artifact ZIP file
2. Extract to your deployment directory
3. Create virtual environment: python3 -m venv venv
4. Activate: source venv/bin/activate
5. Install dependencies: pip install -r requirements.txt
6. Configure environment variables
7. Start the application

## Previous Artifacts

ARTIFACTREADME
                    
                    # List existing artifacts in README
                    echo "" >> ${ARTIFACT_DIR}/README.md
                    echo "| Version | Filename | Size |" >> ${ARTIFACT_DIR}/README.md
                    echo "|---------|----------|------|" >> ${ARTIFACT_DIR}/README.md
                    
                    for artifact in ${ARTIFACT_DIR}/*.zip; do
                        if [ -f "$artifact" ]; then
                            artifact_name=$(basename "$artifact")
                            artifact_size=$(du -h "$artifact" | cut -f1)
                            artifact_version=$(echo "$artifact_name" | sed 's/blog-app-\\(.*\\)\\.zip/\\1/')
                            echo "| ${artifact_version} | ${artifact_name} | ${artifact_size} |" >> ${ARTIFACT_DIR}/README.md
                        fi
                    done
                    
                    echo "" >> ${ARTIFACT_DIR}/README.md
                    echo "## Last Updated" >> ${ARTIFACT_DIR}/README.md
                    echo "" >> ${ARTIFACT_DIR}/README.md
                    echo "**Timestamp**: $(date)" >> ${ARTIFACT_DIR}/README.md
                    echo "" >> ${ARTIFACT_DIR}/README.md
                    echo "**Build Number**: ${BUILD_NUMBER}" >> ${ARTIFACT_DIR}/README.md
                    echo "" >> ${ARTIFACT_DIR}/README.md
                    echo "**Commit Hash**: ${COMMIT_HASH}" >> ${ARTIFACT_DIR}/README.md
                    echo "" >> ${ARTIFACT_DIR}/README.md
                    echo "**Artifact Name**: ${ARTIFACT_NAME}.zip" >> ${ARTIFACT_DIR}/README.md
                    
                    # Show artifact info
                    echo ""
                    echo "=== Artifact Generated ==="
                    echo "Location: ${ARTIFACT_DIR}/${ARTIFACT_FILE}"
                    ls -lh ${ARTIFACT_DIR}/${ARTIFACT_FILE}
                    echo ""
                    echo "Contents of ${ARTIFACT_DIR}:"
                    ls -la ${ARTIFACT_DIR}/ | sed 's/^/  /'
                    echo ""
                    echo "✅ Deployment artifact generated successfully: ${ARTIFACT_FILE}"
                '''
                
                // Archive the artifact in Jenkins
                archiveArtifacts artifacts: 'artifacts/jenkins/*.zip', fingerprint: true
            }
        }
        
        stage('Commit Documentation and Artifacts to GitHub') {
            steps {
                echo '📤 Committing documentation and artifacts to GitHub with retry logic...'
                sh '''
                    echo "=== Committing Documentation and Artifacts with Retry Logic ==="
                    
                    # Function to attempt commit and push
                    attempt_push() {
                        local attempt=$1
                        echo ""
                        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                        echo "Attempt $attempt of ${MAX_RETRIES}"
                        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                        
                        # Fetch latest changes
                        echo "Fetching latest from origin/main..."
                        git fetch origin main
                        
                        # Get current status
                        LOCAL_COMMIT=$(git rev-parse HEAD)
                        REMOTE_COMMIT=$(git rev-parse origin/main)
                        
                        echo "Local commit:  $LOCAL_COMMIT"
                        echo "Remote commit: $REMOTE_COMMIT"
                        
                        # Check if we're behind
                        if [ "$LOCAL_COMMIT" != "$REMOTE_COMMIT" ]; then
                            BEHIND=$(git rev-list HEAD..origin/main --count)
                            echo "⚠️  Local is $BEHIND commit(s) behind remote"
                            
                            echo "Rebasing onto origin/main..."
                            if git rebase origin/main; then
                                echo "✅ Rebase successful"
                            else
                                echo "⚠️  Rebase had conflicts, attempting to resolve..."
                                
                                # Check if conflicts are in our paths
                                CONFLICTS=$(git diff --name-only --diff-filter=U 2>/dev/null || echo "")
                                echo "Conflicts in: $CONFLICTS"
                                
                                # Resolve conflicts in our directories
                                if echo "$CONFLICTS" | grep -qE "docs/jenkins-doc/|artifacts/jenkins/|documentation/master_documentation"; then
                                    echo "Conflict in jenkins paths or LaTeX docs, using our version..."
                                    git checkout --ours docs/jenkins-doc/ 2>/dev/null || true
                                    git checkout --ours artifacts/jenkins/ 2>/dev/null || true
                                    git checkout --ours documentation/master_documentation.tex 2>/dev/null || true
                                    git checkout --ours documentation/master_documentation.pdf 2>/dev/null || true
                                    git add docs/jenkins-doc/ 2>/dev/null || true
                                    git add artifacts/jenkins/ 2>/dev/null || true
                                    git add documentation/master_documentation.tex 2>/dev/null || true
                                    git add documentation/master_documentation.pdf 2>/dev/null || true
                                    git rebase --continue || {
                                        git rebase --skip 2>/dev/null || true
                                    }
                                else
                                    echo "Conflicts outside our paths, aborting rebase..."
                                    git rebase --abort
                                    return 1
                                fi
                            fi
                        else
                            echo "✅ Already up to date with remote"
                        fi
                        
                        # Save the updated LaTeX files before git operations
                        echo "=== Preserving updated LaTeX files ==="
                        if [ -f "documentation/master_documentation.tex" ]; then
                            cp documentation/master_documentation.tex documentation/master_documentation.tex.updated || true
                        fi
                        if [ -f "documentation/master_documentation.pdf" ]; then
                            cp documentation/master_documentation.pdf documentation/master_documentation.pdf.updated || true
                        fi
                        
                        # Check if files exist
                        HAS_CHANGES=false
                        
                        if [ -d "${DOC_DIR}" ] && [ "$(ls -A ${DOC_DIR} 2>/dev/null)" ]; then
                            git add ${DOC_DIR}/
                            HAS_CHANGES=true
                        fi
                        
                        if [ -d "${ARTIFACT_DIR}" ] && [ "$(ls -A ${ARTIFACT_DIR} 2>/dev/null)" ]; then
                            git add ${ARTIFACT_DIR}/
                            HAS_CHANGES=true
                        fi
                        
                        # Add LaTeX documentation files
                        if [ -f "documentation/master_documentation.tex" ]; then
                            git add documentation/master_documentation.tex
                            HAS_CHANGES=true
                        fi
                        if [ -f "documentation/master_documentation.pdf" ]; then
                            git add documentation/master_documentation.pdf
                            HAS_CHANGES=true
                        fi
                        
                        # Restore updated files if they were overwritten by git operations
                        if [ -f "documentation/master_documentation.tex.updated" ]; then
                            cp documentation/master_documentation.tex.updated documentation/master_documentation.tex || true
                            git add documentation/master_documentation.tex
                        fi
                        if [ -f "documentation/master_documentation.pdf.updated" ]; then
                            cp documentation/master_documentation.pdf.updated documentation/master_documentation.pdf || true
                            git add documentation/master_documentation.pdf
                        fi
                        
                        if [ "$HAS_CHANGES" = false ]; then
                            echo "⚠️  No files found to commit"
                            return 0
                        fi
                        
                        # Check if there are staged changes
                        if git diff --cached --quiet; then
                            echo "ℹ️  No changes to commit - skipping"
                            return 0
                        fi
                        
                        # Get commit hash and version for commit message
                        COMMIT_HASH=$(git rev-parse --short=7 HEAD)
                        VERSION="${VERSION_MAJOR}.${VERSION_MINOR}.${BUILD_NUMBER}"
                        
                        # Commit changes
                        echo "Committing changes..."
                        git commit -m "build(jenkins): Add artifact for commit ${COMMIT_HASH} and update documentation [Build #${BUILD_NUMBER}]

Generated by Jenkins Pipeline:
- Deployment artifact: blog-app-${COMMIT_HASH}.zip
- Commit Hash: ${COMMIT_HASH}
- Version: ${VERSION}
- UML documentation updates
- Class and package diagrams
- LaTeX master documentation updated and compiled

[skip ci]"
                        
                        # Clean up temporary files
                        rm -f documentation/master_documentation.tex.updated documentation/master_documentation.pdf.updated
                        
                        # Push to repository
                        echo "Pushing to repository..."
                        if git push https://${GITHUB_TOKEN}@github.com/${GITHUB_REPO}.git HEAD:main; then
                            echo "✅ Successfully pushed"
                            return 0
                        else
                            echo "❌ Push failed"
                            return 1
                        fi
                    }
                    
                    # Configure git
                    git config user.email "jenkins@ci.local"
                    git config user.name "Jenkins CI"
                    
                    # Retry loop
                    SUCCESS=false
                    for i in $(seq 1 ${MAX_RETRIES}); do
                        if attempt_push $i; then
                            SUCCESS=true
                            break
                        else
                            if [ $i -lt ${MAX_RETRIES} ]; then
                                echo ""
                                echo "⏳ Waiting ${RETRY_DELAY} seconds before retry..."
                                sleep ${RETRY_DELAY}
                            fi
                        fi
                    done
                    
                    if [ "$SUCCESS" = true ]; then
                        echo ""
                        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                        echo "✅ Documentation and artifacts successfully committed and pushed"
                        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                    else
                        echo ""
                        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                        echo "⚠️  Failed to push after ${MAX_RETRIES} attempts"
                        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                        echo ""
                        echo "This is not critical - continuing with deployment"
                        echo "Artifacts are still archived in Jenkins"
                    fi
                '''
            }
        }
        
        stage('Deploy to DigitalOcean Droplet 2') {
            steps {
                echo '🚀 Deploying to DigitalOcean Droplet 2...'
                echo "Branch: ${env.GIT_BRANCH}"
                echo "Build Number: ${env.BUILD_NUMBER}"
                
                script {
                    sshagent(credentials: ['droplet2-ssh-key']) {
                        // Write the deployment script to a temporary file
                        writeFile file: 'deploy_script.sh', text: """#!/bin/bash
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

# Discard any local changes
echo ""
echo "🧹 Cleaning local repository..."
git reset --hard HEAD
git clean -fd

# Fetch latest from remote
echo ""
echo "📥 Fetching latest code from remote..."
git fetch origin main

# Force reset to match remote (handles divergent branches)
echo ""
echo "🔄 Resetting to origin/main..."
git reset --hard origin/main

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

# Update environment variables
echo ""
echo "⚙️  Updating environment variables..."
echo "SECRET_KEY=${SECRET_KEY}" > .env
echo "MONGO_URI=${MONGO_URI}" >> .env
echo "DATABASE_NAME=${DATABASE_NAME}" >> .env
echo "FLASK_ENV=production" >> .env
echo "FLASK_DEBUG=False" >> .env
chmod 600 .env
echo "✅ Environment file updated"

# Verify .env file was created
if [ -f .env ]; then
    echo "✅ .env file exists with \$(wc -l < .env) lines"
else
    echo "❌ .env file was not created!"
    exit 1
fi

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
"""
                        
                        // Execute the deployment
                        sh """
                            echo "Connecting to ${DROPLET2_HOST}..."
                            cat deploy_script.sh | ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 ${DROPLET2_USER}@${DROPLET2_HOST} 'bash -s'
                            rm -f deploy_script.sh
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
                
                # Clean up any leftover deploy script
                rm -f deploy_script.sh
                
                echo "✅ Cleanup complete"
            '''
        }
        success {
            echo '✅ Pipeline completed successfully!'
            echo "Build #${BUILD_NUMBER} - SUCCESS"
            echo "Artifact: blog-app-${VERSION_MAJOR}.${VERSION_MINOR}.${BUILD_NUMBER}.zip"
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
            echo '  - Documentation push failing: Check GITHUB_TOKEN credential'
        }
        unstable {
            echo '⚠️  Pipeline completed with warnings'
            echo 'Some tests may have failed or coverage is low'
        }
    }
}