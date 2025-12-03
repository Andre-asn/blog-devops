#!/bin/bash
# Install Git hooks by creating symbolic links
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

# Check if hooks are executable
echo "Step 1: Making hooks executable..."
chmod +x hooks/pre-commit 2>/dev/null || true
chmod +x hooks/pre-push 2>/dev/null || true
echo -e "${GREEN}✓ Hooks are now executable${NC}"
echo ""

# Create symbolic links
echo "Step 2: Installing hooks via symbolic links..."

HOOKS_TO_INSTALL=("pre-commit" "pre-push")
INSTALLED_COUNT=0
UPDATED_COUNT=0
SKIPPED_COUNT=0

for hook in "${HOOKS_TO_INSTALL[@]}"; do
    SOURCE_HOOK="../../hooks/$hook"
    TARGET_HOOK=".git/hooks/$hook"
    
    echo -n "  Installing $hook... "
    
    # Check if hook already exists
    if [ -e "$TARGET_HOOK" ] || [ -L "$TARGET_HOOK" ]; then
        # Check if it's already a symlink to our hook
        if [ -L "$TARGET_HOOK" ]; then
            CURRENT_TARGET=$(readlink "$TARGET_HOOK")
            if [ "$CURRENT_TARGET" = "$SOURCE_HOOK" ]; then
                echo -e "${BLUE}already installed ✓${NC}"
                SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
                continue
            fi
        fi
        
        # Backup existing hook
        BACKUP_NAME="$TARGET_HOOK.backup.$(date +%Y%m%d_%H%M%S)"
        mv "$TARGET_HOOK" "$BACKUP_NAME"
        echo -e "${YELLOW}backed up existing hook${NC}"
        echo -n "    Creating new link... "
        UPDATED_COUNT=$((UPDATED_COUNT + 1))
    else
        INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
    fi
    
    # Create symbolic link
    ln -s "$SOURCE_HOOK" "$TARGET_HOOK"
    echo -e "${GREEN}done ✓${NC}"
done

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  Installation Summary"
echo "═══════════════════════════════════════════════════════"
echo "  Newly installed:  $INSTALLED_COUNT"
echo "  Updated:          $UPDATED_COUNT"
echo "  Already installed: $SKIPPED_COUNT"
echo "═══════════════════════════════════════════════════════"
echo ""

# Verify installation
echo "Step 3: Verifying installation..."
ALL_GOOD=true

for hook in "${HOOKS_TO_INSTALL[@]}"; do
    TARGET_HOOK=".git/hooks/$hook"
    
    if [ -L "$TARGET_HOOK" ]; then
        LINK_TARGET=$(readlink "$TARGET_HOOK")
        if [ -f "hooks/$hook" ]; then
            echo -e "${GREEN}✓ $hook → $LINK_TARGET (valid)${NC}"
        else
            echo -e "${RED}✗ $hook → $LINK_TARGET (broken link!)${NC}"
            ALL_GOOD=false
        fi
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

# Check Pylint installation
echo "Step 4: Checking dependencies..."

if command -v pylint &> /dev/null; then
    PYLINT_VERSION=$(pylint --version | head -1)
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
    if grep -q "pylint" requirements.txt; then
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

echo ""
echo "╔════════════════════════════════════════════════════════╗"
echo "║           Installation Complete! ✅                    ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""
echo "What happens now:"
echo ""
echo "  📝 ${BLUE}pre-commit hook:${NC}"
echo "     • Runs automatically on every 'git commit'"
echo "     • Checks staged Python files with Pylint"
echo "     • Blocks commit if errors found"
echo "     • Allows warnings (non-blocking)"
echo ""
echo "  🚀 ${BLUE}pre-push hook:${NC}"
echo "     • Runs automatically when pushing to main/master"
echo "     • Checks ALL Python files in repository"
echo "     • Blocks push if errors found"
echo "     • More comprehensive than pre-commit"
echo ""
echo "Useful commands:"
echo "  • Test pre-commit: create a .py file with error, stage, and commit"
echo "  • Skip pre-commit: git commit --no-verify"
echo "  • Skip pre-push:  git push --no-verify"
echo "  • Check manually: pylint <filename>"
echo "  • Uninstall hooks: rm .git/hooks/pre-commit .git/hooks/pre-push"
echo ""
echo "Testing the installation..."
echo ""

# Quick test
echo "Creating a test file with intentional error..."
TEST_FILE="test_hook_install.py"
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
        echo -e "${GREEN}✓ Pylint correctly detected the error${NC}"
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
echo "Happy coding! 🚀"
