#!/bin/bash
# Install Git hooks by copying files to .git/hooks/
# This script should be run once by each developer after cloning the repository

set -e

echo "╔════════════════════════════════════════════════════════╗"
echo "║        Git Hooks Installation Script                   ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Check if we're in a git repository
if [ ! -d .git ]; then
    echo -e "${RED}❌ Error: Not in a git repository root${NC}"
    echo "Please run this script from the repository root directory"
    exit 1
fi

# Check if hooks directory exists
if [ ! -d hooks ]; then
    echo -e "${RED}❌ Error: hooks/ directory not found${NC}"
    echo "This script should be run from the repository root"
    exit 1
fi

echo "Current directory: $(pwd)"
echo ""

#===============================================================================
# JENKINS CONFIGURATION
#===============================================================================
echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║         JENKINS PIPELINE CONFIGURATION                 ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "The pre-push hook can trigger a Jenkins pipeline after successful pushes."
echo ""

# Check if pre-push hook has placeholder values
NEEDS_JENKINS_CONFIG=false
if [ -f hooks/pre-push ]; then
    if grep -q 'JENKINS_USER="your-jenkins-username"' hooks/pre-push || \
       grep -q 'JENKINS_TOKEN="your-jenkins-api-token"' hooks/pre-push; then
        NEEDS_JENKINS_CONFIG=true
    fi
fi

# Ask user if they want to configure Jenkins
read -p "Do you want to configure Jenkins pipeline trigger? (y/n) [y]: " CONFIGURE_JENKINS
CONFIGURE_JENKINS=${CONFIGURE_JENKINS:-y}

if [[ "$CONFIGURE_JENKINS" =~ ^[Yy]$ ]]; then
    echo ""
    echo -e "${BLUE}Jenkins Configuration${NC}"
    echo "─────────────────────────────────────────────────────────"
    echo ""
    
    # Get current values if they exist
    CURRENT_URL=$(grep 'JENKINS_URL=' hooks/pre-push | head -1 | cut -d'"' -f2)
    CURRENT_USER=$(grep 'JENKINS_USER=' hooks/pre-push | head -1 | cut -d'"' -f2)
    CURRENT_JOB=$(grep 'JENKINS_JOB=' hooks/pre-push | head -1 | cut -d'"' -f2)
    CURRENT_BRANCH=$(grep 'TRIGGER_JENKINS_ON_BRANCH=' hooks/pre-push | head -1 | cut -d'"' -f2)
    
    # Set defaults
    DEFAULT_URL="${CURRENT_URL:-http://localhost:8080}"
    DEFAULT_USER="${CURRENT_USER:-}"
    DEFAULT_JOB="${CURRENT_JOB:-blog-app-pipeline}"
    DEFAULT_BRANCH="${CURRENT_BRANCH:-main}"
    
    # Don't show current token for security
    if [ "$CURRENT_USER" = "your-jenkins-username" ]; then
        DEFAULT_USER=""
    fi
    
    read -p "Jenkins URL [$DEFAULT_URL]: " JENKINS_URL
    JENKINS_URL=${JENKINS_URL:-$DEFAULT_URL}
    
    read -p "Jenkins Username: " JENKINS_USER
    if [ -z "$JENKINS_USER" ]; then
        echo -e "${RED}❌ Jenkins username is required${NC}"
        exit 1
    fi
    
    echo ""
    echo -e "${YELLOW}To get your Jenkins API Token:${NC}"
    echo "  1. Go to Jenkins → Your username (top right) → Configure"
    echo "  2. Click 'Add new Token' under API Token"
    echo "  3. Give it a name and click 'Generate'"
    echo "  4. Copy the token"
    echo ""
    
    read -sp "Jenkins API Token: " JENKINS_TOKEN
    echo ""
    if [ -z "$JENKINS_TOKEN" ]; then
        echo -e "${RED}❌ Jenkins API token is required${NC}"
        exit 1
    fi
    
    read -p "Jenkins Job Name [$DEFAULT_JOB]: " JENKINS_JOB
    JENKINS_JOB=${JENKINS_JOB:-$DEFAULT_JOB}
    
    read -p "Branch to trigger Jenkins on [$DEFAULT_BRANCH]: " TRIGGER_BRANCH
    TRIGGER_BRANCH=${TRIGGER_BRANCH:-$DEFAULT_BRANCH}
    
    echo ""
    echo -e "${BLUE}Testing Jenkins connection...${NC}"
    
    # Test Jenkins connection
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 \
        -u "${JENKINS_USER}:${JENKINS_TOKEN}" \
        "${JENKINS_URL}/job/${JENKINS_JOB}/api/json" 2>/dev/null || echo "000")
    
    if [ "$HTTP_CODE" = "200" ]; then
        echo -e "${GREEN}✅ Successfully connected to Jenkins job: ${JENKINS_JOB}${NC}"
    elif [ "$HTTP_CODE" = "401" ]; then
        echo -e "${YELLOW}⚠️  Authentication failed (401). Check username and API token.${NC}"
        read -p "Continue anyway? (y/n) [n]: " CONTINUE
        if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
            exit 1
        fi
    elif [ "$HTTP_CODE" = "404" ]; then
        echo -e "${YELLOW}⚠️  Job '${JENKINS_JOB}' not found (404).${NC}"
        read -p "Continue anyway? (y/n) [n]: " CONTINUE
        if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
            exit 1
        fi
    elif [ "$HTTP_CODE" = "000" ]; then
        echo -e "${YELLOW}⚠️  Could not connect to Jenkins at ${JENKINS_URL}${NC}"
        echo "    Make sure Jenkins is running when you push."
        read -p "Continue anyway? (y/n) [y]: " CONTINUE
        CONTINUE=${CONTINUE:-y}
        if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        echo -e "${YELLOW}⚠️  Unexpected response: ${HTTP_CODE}${NC}"
        read -p "Continue anyway? (y/n) [y]: " CONTINUE
        CONTINUE=${CONTINUE:-y}
        if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    JENKINS_CONFIGURED=true
else
    echo -e "${YELLOW}⚠️  Skipping Jenkins configuration${NC}"
    echo "    You can configure it later by editing .git/hooks/pre-push"
    JENKINS_CONFIGURED=false
fi

echo ""

#===============================================================================
# INSTALL HOOKS
#===============================================================================
echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║              INSTALLING GIT HOOKS                      ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# Make source hooks executable
echo "Step 1: Making source hooks executable..."
chmod +x hooks/pre-commit 2>/dev/null || true
chmod +x hooks/pre-push 2>/dev/null || true
echo -e "${GREEN}✓ Source hooks are now executable${NC}"
echo ""

# Copy hooks to .git/hooks/
echo "Step 2: Copying hooks to .git/hooks/..."

HOOKS_TO_INSTALL=("pre-commit" "pre-push")
INSTALLED_COUNT=0
UPDATED_COUNT=0

for hook in "${HOOKS_TO_INSTALL[@]}"; do
    SOURCE_HOOK="hooks/$hook"
    TARGET_HOOK=".git/hooks/$hook"
    
    echo -n "  Installing $hook... "
    
    # Check if source hook exists
    if [ ! -f "$SOURCE_HOOK" ]; then
        echo -e "${RED}source not found!${NC}"
        continue
    fi
    
    # Check if hook already exists
    if [ -f "$TARGET_HOOK" ]; then
        # Check if it's a symlink (from old installation)
        if [ -L "$TARGET_HOOK" ]; then
            rm "$TARGET_HOOK"
            echo -n "(removed old symlink) "
        else
            # Backup existing hook
            BACKUP_NAME="$TARGET_HOOK.backup.$(date +%Y%m%d_%H%M%S)"
            mv "$TARGET_HOOK" "$BACKUP_NAME"
            echo -e "${YELLOW}backed up existing hook${NC}"
            echo -n "    Creating new copy... "
        fi
        UPDATED_COUNT=$((UPDATED_COUNT + 1))
    else
        INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
    fi
    
    # Copy the hook file
    cp "$SOURCE_HOOK" "$TARGET_HOOK"
    
    # If Jenkins was configured, update the pre-push hook with the configuration
    if [ "$hook" = "pre-push" ] && [ "$JENKINS_CONFIGURED" = true ]; then
        # Update Jenkins configuration in the copied hook
        sed -i.tmp "s|^JENKINS_URL=.*|JENKINS_URL=\"${JENKINS_URL}\"|" "$TARGET_HOOK"
        sed -i.tmp "s|^JENKINS_USER=.*|JENKINS_USER=\"${JENKINS_USER}\"|" "$TARGET_HOOK"
        sed -i.tmp "s|^JENKINS_TOKEN=.*|JENKINS_TOKEN=\"${JENKINS_TOKEN}\"|" "$TARGET_HOOK"
        sed -i.tmp "s|^JENKINS_JOB=.*|JENKINS_JOB=\"${JENKINS_JOB}\"|" "$TARGET_HOOK"
        sed -i.tmp "s|^TRIGGER_JENKINS_ON_BRANCH=.*|TRIGGER_JENKINS_ON_BRANCH=\"${TRIGGER_BRANCH}\"|" "$TARGET_HOOK"
        rm -f "$TARGET_HOOK.tmp"
    fi
    
    # Make the copied hook executable
    chmod +x "$TARGET_HOOK"
    
    echo -e "${GREEN}done ✓${NC}"
done

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  Installation Summary"
echo "═══════════════════════════════════════════════════════"
echo "  Newly installed:  $INSTALLED_COUNT"
echo "  Updated:          $UPDATED_COUNT"
echo "═══════════════════════════════════════════════════════"
echo ""

# Verify installation
echo "Step 3: Verifying installation..."
ALL_GOOD=true

for hook in "${HOOKS_TO_INSTALL[@]}"; do
    TARGET_HOOK=".git/hooks/$hook"
    
    if [ -f "$TARGET_HOOK" ] && [ -x "$TARGET_HOOK" ]; then
        FILE_SIZE=$(wc -c < "$TARGET_HOOK" | tr -d ' ')
        echo -e "${GREEN}✓ $hook (${FILE_SIZE} bytes, executable)${NC}"
    elif [ -f "$TARGET_HOOK" ]; then
        echo -e "${YELLOW}⚠ $hook (exists but not executable)${NC}"
        chmod +x "$TARGET_HOOK"
        echo -e "  ${GREEN}→ Fixed: made executable${NC}"
    else
        echo -e "${RED}✗ $hook (not installed)${NC}"
        ALL_GOOD=false
    fi
done

echo ""

if [ "$ALL_GOOD" = false ]; then
    echo -e "${RED}❌ Some hooks were not installed correctly${NC}"
    exit 1
fi

#===============================================================================
# CHECK DEPENDENCIES
#===============================================================================
echo "Step 4: Checking dependencies..."

if command -v pylint &> /dev/null; then
    PYLINT_VERSION=$(pylint --version 2>/dev/null | head -1)
    echo -e "${GREEN}✓ Pylint is installed: $PYLINT_VERSION${NC}"
else
    echo -e "${YELLOW}⚠️  Pylint is not installed${NC}"
    echo ""
    echo "The hooks require Pylint to work. Install it with:"
    echo ""
    
    if [ -f "venv/bin/activate" ] || [ -f ".venv/bin/activate" ]; then
        echo "  # If using virtual environment:"
        echo "  source venv/bin/activate  # or source .venv/bin/activate"
        echo "  pip install pylint"
    else
        echo "  pip install pylint"
        echo ""
        echo "  # Or if using virtual environment:"
        echo "  source venv/bin/activate"
        echo "  pip install pylint"
    fi
    echo ""
fi

# Check if requirements.txt has pylint
if [ -f requirements.txt ]; then
    if grep -qi "pylint" requirements.txt; then
        echo -e "${GREEN}✓ Pylint is in requirements.txt${NC}"
    else
        echo -e "${YELLOW}⚠️  Pylint is not in requirements.txt${NC}"
        echo "  Consider adding it: echo 'pylint==3.0.3' >> requirements.txt"
    fi
fi

# Check for .pylintrc
if [ -f .pylintrc ]; then
    echo -e "${GREEN}✓ .pylintrc configuration found${NC}"
else
    echo -e "${YELLOW}⚠️  .pylintrc not found${NC}"
    echo "  Pylint will use default configuration"
fi

# Check curl for Jenkins trigger
if command -v curl &> /dev/null; then
    echo -e "${GREEN}✓ curl is installed (required for Jenkins trigger)${NC}"
else
    echo -e "${YELLOW}⚠️  curl is not installed${NC}"
    echo "  Jenkins trigger will not work without curl"
fi

echo ""

#===============================================================================
# COMPLETION
#===============================================================================
echo "╔════════════════════════════════════════════════════════╗"
echo "║           Installation Complete! ✅                    ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""
echo "What happens now:"
echo ""
echo -e "  📝 ${BLUE}pre-commit hook:${NC}"
echo "     • Runs automatically on every 'git commit'"
echo "     • Checks staged Python files with Pylint"
echo "     • Blocks commit if errors found"
echo "     • Allows warnings (non-blocking)"
echo ""
echo -e "  🚀 ${BLUE}pre-push hook:${NC}"
echo "     • Runs automatically when pushing to main/master"
echo "     • Checks Python files changed in commits being pushed"
echo "     • Blocks push if errors found"
if [ "$JENKINS_CONFIGURED" = true ]; then
    echo -e "     • ${GREEN}Triggers Jenkins pipeline after successful push${NC}"
    echo "       Job: ${JENKINS_JOB}"
    echo "       URL: ${JENKINS_URL}"
else
    echo -e "     • ${YELLOW}Jenkins trigger not configured${NC}"
    echo "       Edit .git/hooks/pre-push to configure"
fi
echo ""
echo "Useful commands:"
echo "  • Skip pre-commit: git commit --no-verify"
echo "  • Skip pre-push:   git push --no-verify"
echo "  • Check manually:  pylint <filename>"
echo "  • Reinstall hooks: ./hooks/install-hooks.sh"
echo "  • Uninstall hooks: rm .git/hooks/pre-commit .git/hooks/pre-push"
echo ""

#===============================================================================
# QUICK TEST
#===============================================================================
echo "Step 5: Running quick test..."
echo ""

# Quick test
echo "Creating a test file with intentional error..."
TEST_FILE=".test_hook_install_temp.py"
cat > "$TEST_FILE" << 'EOF'
# Test file - will be deleted
def broken(:
    pass
EOF

if [ -f "$TEST_FILE" ]; then
    echo "Running Pylint on test file..."
    set +e
    pylint "$TEST_FILE" > /dev/null 2>&1
    PYLINT_EXIT=$?
    set -e
    
    if [ $PYLINT_EXIT -ne 0 ]; then
        echo -e "${GREEN}✓ Pylint correctly detected the syntax error${NC}"
    else
        echo -e "${YELLOW}⚠️  Pylint did not detect error (unexpected)${NC}"
    fi
    
    rm -f "$TEST_FILE"
    echo "Test file cleaned up"
else
    echo -e "${YELLOW}⚠️  Could not create test file${NC}"
fi

echo ""
echo -e "${GREEN}🎉 Git hooks are ready to use!${NC}"
echo ""
echo "Your commits and pushes are now protected by Pylint checks."
if [ "$JENKINS_CONFIGURED" = true ]; then
    echo -e "Jenkins pipeline will be triggered on successful pushes to ${TRIGGER_BRANCH}."
fi
echo ""
echo "Happy coding! 🚀"