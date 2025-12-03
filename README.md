# Blog Application - DevOps Pipeline

A Flask-based blog application with comprehensive CI/CD pipelines using both **Jenkins** and **GitHub Actions**, deploying to **DigitalOcean Droplets**.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Local Development Setup](#local-development-setup)
- [CI/CD Pipelines](#cicd-pipelines)
  - [GitHub Actions Pipeline](#github-actions-pipeline)
  - [Jenkins Pipeline](#jenkins-pipeline)
- [Git Hooks](#git-hooks)
- [Deployment](#deployment)
- [Artifacts & Versioning](#artifacts--versioning)
- [Documentation Generation](#documentation-generation)
- [Monitoring](#monitoring)
- [Troubleshooting](#troubleshooting)

---

## Overview

This project implements a dual CI/CD pipeline architecture:

| Pipeline | Target | Trigger |
|----------|--------|---------|
| GitHub Actions | Droplet 1 | Push to `main` branch |
| Jenkins | Droplet 2 | Git pre-push hook / Manual |

Both pipelines perform testing, documentation generation, artifact creation, and deployment with health checks.

---

## Architecture

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│   Developer     │────▶│     GitHub       │────▶│  GitHub Actions │
│   Workstation   │     │   Repository     │     │    Pipeline     │
└────────┬────────┘     └──────────────────┘     └────────┬────────┘
         │                                                 │
         │ pre-push hook                                   ▼
         │                                        ┌─────────────────┐
         ▼                                        │   Droplet 1     │
┌─────────────────┐                               │  (Production)   │
│     Jenkins     │                               └─────────────────┘
│    Pipeline     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   Droplet 2     │
│  (Production)   │
└─────────────────┘
```

---

## Tech Stack

| Component | Technology |
|-----------|------------|
| Backend | Flask (Python 3.11) |
| Database | MongoDB |
| WSGI Server | Gunicorn |
| Monitoring | Prometheus metrics |
| CI/CD | GitHub Actions, Jenkins |
| Infrastructure | DigitalOcean Droplets |
| Code Quality | Pylint, Pytest |
| Documentation | Pyreverse, Graphviz |

---

## Project Structure

```
blog-devops/
├── app.py                    # Flask application entry point
├── requirements.txt          # Python dependencies
├── .pylintrc                 # Pylint configuration
├── Jenkinsfile               # Jenkins pipeline definition
├── .github/
│   └── workflows/
│       └── ci-cd.yml         # GitHub Actions workflow
├── hooks/
│   ├── pre-commit            # Pre-commit hook (Pylint)
│   ├── pre-push              # Pre-push hook (Pylint + Jenkins trigger)
│   └── install-hooks.sh      # Hook installation script
├── templates/                # HTML templates
├── static/                   # Static assets
├── tests/                    # Test files
├── documentations/
│   ├── actions-doc/          # GitHub Actions generated docs
│   └── jenkins-doc/          # Jenkins generated docs
└── artifacts/
    ├── actions/              # GitHub Actions artifacts
    └── jenkins/              # Jenkins artifacts
```

---

## Prerequisites

### Local Development

- Python 3.11+
- MongoDB 7.0+
- Git
- Pylint (`pip install pylint`)

### For Jenkins Pipeline (macOS)

- Jenkins installed locally
- Homebrew
- Graphviz (`brew install graphviz`)
- MongoDB (`brew install mongodb-community`)

### For Deployment

- DigitalOcean Droplets with:
  - Ubuntu 24.04
  - Python 3.11+
  - MongoDB
  - Systemd service configured

---

## Local Development Setup

### 1. Clone Repository

```bash
git clone https://github.com/Andre-asn/blog-devops.git
cd blog-devops
```

### 2. Create Virtual Environment

```bash
python3 -m venv venv
source venv/bin/activate  # Linux/macOS
# or
.\venv\Scripts\activate   # Windows
```

### 3. Install Dependencies

```bash
pip install --upgrade pip
pip install -r requirements.txt
pip install pylint  # For code quality checks
```

### 4. Configure Environment

Create a `.env` file:

```env
SECRET_KEY=your-secret-key-here
MONGO_URI=mongodb://localhost:27017/
DATABASE_NAME=blog_db
FLASK_ENV=development
FLASK_DEBUG=True
```

### 5. Start MongoDB

```bash
# macOS
brew services start mongodb-community

# Linux
sudo systemctl start mongod
```

### 6. Run Application

```bash
python app.py
# or
flask run
```

Access at: `http://localhost:5000`

### 7. Install Git Hooks

```bash
chmod +x hooks/install-hooks.sh
./hooks/install-hooks.sh
```

---

## CI/CD Pipelines

### GitHub Actions Pipeline

**File**: `.github/workflows/ci-cd.yml`

**Trigger**: Push to `main` branch

**Jobs**:

| Job | Description |
|-----|-------------|
| `test` | Run Pytest with coverage |
| `generate-documentation` | Generate UML diagrams with Pyreverse |
| `generate-artifact` | Create versioned deployment ZIP |
| `deploy` | Deploy to Droplet 1 |
| `notify` | Report deployment status |

**Required Secrets** (Repository → Settings → Secrets):

| Secret | Description |
|--------|-------------|
| `DIGITALOCEAN_HOST` | Droplet 1 IP address |
| `DIGITALOCEAN_USER` | SSH username |
| `DIGITALOCEAN_SSH_KEY` | Private SSH key |
| `APP_DIRECTORY` | Application path on droplet |
| `SECRET_KEY` | Flask secret key |
| `MONGO_URI` | MongoDB connection string |
| `DATABASE_NAME` | Database name |

**Setup**:

1. Add secrets in GitHub repository settings
2. Enable workflow permissions:
   - Repository → Settings → Actions → General
   - Select "Read and write permissions"
   - Check "Allow GitHub Actions to create and approve pull requests"

---

### Jenkins Pipeline

**File**: `Jenkinsfile`

**Trigger**: Git pre-push hook or manual build

**Stages**:

| Stage | Description |
|-------|-------------|
| Checkout | Clone repository |
| Setup Python Environment | Create venv, install dependencies |
| Check MongoDB | Verify MongoDB connection |
| Run Tests | Execute Pytest with coverage |
| Generate Test Reports | Publish JUnit and coverage reports |
| Sync with Remote | Pull latest changes |
| Generate Pyreverse Documentation | Create UML diagrams |
| Generate Deployment Artifact | Create versioned ZIP |
| Commit to GitHub | Push docs and artifacts |
| Deploy to Droplet 2 | Deploy application |

**Required Credentials** (Jenkins → Manage Credentials):

| Credential ID | Type | Description |
|---------------|------|-------------|
| `droplet2-host` | Secret text | Droplet 2 IP address |
| `droplet2-user` | Secret text | SSH username |
| `droplet2-ssh-key` | SSH Key | Private SSH key |
| `droplet2-app-dir` | Secret text | Application path |
| `mongo-uri` | Secret text | MongoDB connection string |
| `secret-key` | Secret text | Flask secret key |
| `database-name` | Secret text | Database name |
| `github-token` | Secret text | GitHub PAT with `repo` scope |

**Setup**:

1. Create Jenkins job:
   - New Item → Pipeline
   - Name: `blog-app-pipeline`
   - Pipeline from SCM → Git
   - Repository URL: `https://github.com/Andre-asn/blog-devops.git`
   - Branch: `*/main`
   - Script Path: `Jenkinsfile`

2. Add credentials in Jenkins

3. Install required plugins:
   - HTML Publisher
   - SSH Agent
   - JUnit

---

## Git Hooks

### Pre-commit Hook

Runs Pylint on staged Python files before each commit.

- **Blocks commit**: If Pylint errors found
- **Allows commit**: If only warnings present

### Pre-push Hook

Runs Pylint on changed files and triggers Jenkins pipeline.

- **Blocks push**: If Pylint errors found on `main`/`master` branch
- **Triggers Jenkins**: After successful push to configured branch

### Installation

```bash
./hooks/install-hooks.sh
```

The installer will:
1. Copy hooks to `.git/hooks/`
2. Prompt for Jenkins configuration
3. Test Jenkins connection
4. Verify Pylint installation

### Configuration

Edit Jenkins settings in `.git/hooks/pre-push`:

```bash
JENKINS_URL="http://localhost:8080"
JENKINS_USER="your-username"
JENKINS_TOKEN="your-api-token"
JENKINS_JOB="blog-app-pipeline"
TRIGGER_JENKINS_ON_BRANCH="main"
```

### Bypass Hooks

```bash
git commit --no-verify  # Skip pre-commit
git push --no-verify    # Skip pre-push
```

---

## Deployment

### Droplet Setup

1. **Install dependencies**:

```bash
sudo apt update
sudo apt install python3.11 python3.11-venv python3-pip mongodb-org nginx
```

2. **Create application directory**:

```bash
sudo mkdir -p /var/www/blog-app
sudo chown $USER:$USER /var/www/blog-app
cd /var/www/blog-app
git clone https://github.com/Andre-asn/blog-devops.git .
```

3. **Setup virtual environment**:

```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

4. **Create systemd service** (`/etc/systemd/system/blog-app.service`):

```ini
[Unit]
Description=Blog Application
After=network.target mongod.service

[Service]
User=www-data
Group=www-data
WorkingDirectory=/var/www/blog-app
Environment="PATH=/var/www/blog-app/venv/bin"
EnvironmentFile=/var/www/blog-app/.env
ExecStart=/var/www/blog-app/venv/bin/gunicorn --workers 3 --bind 0.0.0.0:5000 app:app
Restart=always

[Install]
WantedBy=multi-user.target
```

5. **Enable and start services**:

```bash
sudo systemctl daemon-reload
sudo systemctl enable mongod blog-app
sudo systemctl start mongod blog-app
```

### Deployment Flow

Both pipelines follow this deployment process:

1. Clean local repository (`git reset --hard`)
2. Fetch and reset to `origin/main`
3. Install/update dependencies
4. Update `.env` file
5. Restart application service
6. Perform health checks (5 retries)
7. Verify endpoints (`/health`, `/metrics`, `/`)

---

## Artifacts & Versioning

### Version Format

```
major.minor.changelist
  │     │       │
  │     │       └── Build/Run number (auto-incremented)
  │     └────────── Minor version (manual)
  └──────────────── Major version (manual)

Example: 1.0.245
```

### Artifact Contents

| File | Description |
|------|-------------|
| `*.py` | Python source files |
| `templates/` | HTML templates |
| `static/` | Static assets |
| `requirements.txt` | Dependencies |
| `VERSION` | JSON metadata |
| `MANIFEST` | Contents listing |

### Storage Locations

| Pipeline | Directory | Retention |
|----------|-----------|-----------|
| GitHub Actions | `artifacts/actions/` | 90 days |
| Jenkins | `artifacts/jenkins/` | Permanent |

### VERSION File

```json
{
    "version": "1.0.245",
    "major": 1,
    "minor": 0,
    "build": 245,
    "timestamp": "2024-12-03T15:30:00Z",
    "git_commit": "abc123def456...",
    "git_branch": "main",
    "built_by": "Jenkins CI"
}
```

---

## Documentation Generation

Both pipelines generate UML documentation using Pyreverse and Graphviz.

### Generated Files

| File | Description |
|------|-------------|
| `classes_blog_app.dot` | Class diagram (DOT format) |
| `classes_blog_app.png` | Class diagram (PNG) |
| `classes_blog_app.svg` | Class diagram (SVG) |
| `packages_blog_app.dot` | Package diagram (DOT format) |
| `packages_blog_app.png` | Package diagram (PNG) |
| `packages_blog_app.svg` | Package diagram (SVG) |

### Storage Locations

| Pipeline | Directory |
|----------|-----------|
| GitHub Actions | `documentations/actions-doc/` |
| Jenkins | `documentations/jenkins-doc/` |

### Manual Generation

```bash
pip install pylint
sudo apt install graphviz  # or brew install graphviz

pyreverse -o dot -p blog_app *.py
dot -Tpng classes_blog_app.dot -o classes_blog_app.png
dot -Tsvg classes_blog_app.dot -o classes_blog_app.svg
```

---

## Monitoring

### Health Endpoint

```
GET /health
```

Returns application health status.

### Metrics Endpoint

```
GET /metrics
```

Returns Prometheus-compatible metrics with `blog_` prefix.

### Application Logs

```bash
# Systemd journal
sudo journalctl -u blog-app -f

# Application logs
tail -f /var/www/blog-app/logs/error.log
```

---

## Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| MongoDB not running | `brew services start mongodb-community` (macOS) or `sudo systemctl start mongod` (Linux) |
| Jenkins credential error | Verify credential ID matches exactly in Jenkinsfile |
| GitHub Actions push denied | Enable "Read and write permissions" in repository settings |
| Divergent branches error | Pipelines use `git reset --hard origin/main` to handle this |
| Health check failing | Check `.env` file and application logs |
| Pylint blocking commit | Fix errors or use `--no-verify` flag |

### Checking Service Status

```bash
# Application
sudo systemctl status blog-app

# MongoDB
sudo systemctl status mongod

# View logs
sudo journalctl -u blog-app -n 50 --no-pager
```

### Manual Deployment

```bash
cd /var/www/blog-app
git fetch origin main
git reset --hard origin/main
source venv/bin/activate
pip install -r requirements.txt
sudo systemctl restart blog-app
```

### Testing Jenkins Connection

```bash
curl -u "username:api-token" \
  "http://localhost:8080/job/blog-app-pipeline/api/json"
```

---

## License

MIT License

---

## Contact

Project Repository: [https://github.com/Andre-asn/blog-devops](https://github.com/Andre-asn/blog-devops)