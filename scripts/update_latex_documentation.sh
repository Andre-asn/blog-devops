#!/bin/bash
set -e

echo "📝 Updating LaTeX master documentation..."

# Configuration
LATEX_FILE="documentation/master_documentation.tex"
OUTPUT_DIR="documentation"
COMMIT_HASH=$(git rev-parse HEAD)
COMMIT_SHORT=$(git rev-parse --short=7 HEAD)
COMMIT_DATE=$(git log -1 --format=%ci HEAD)
COMMIT_AUTHOR=$(git log -1 --format=%an HEAD)
COMMIT_MESSAGE=$(git log -1 --format=%B HEAD | head -1)

# Get commit changes (will be written directly to file later)
echo "📋 Gathering commit changes..."

# Create documentation directory if it doesn't exist
mkdir -p ${OUTPUT_DIR}

# Read existing LaTeX file or create new one
if [ ! -f "${LATEX_FILE}" ]; then
    echo "❌ LaTeX template file not found at ${LATEX_FILE}"
    exit 1
fi

# Create temporary files
TEMP_FILE=$(mktemp)
DOC_SECTION_FILE=$(mktemp)
CHANGES_SECTION_FILE=$(mktemp)

# Function to escape LaTeX special characters
escape_latex_safe() {
    # Use awk for safer processing
    awk '{
        gsub(/\\/, "\\\\textbackslash{}");
        gsub(/{/, "\\\\{");
        gsub(/}/, "\\\\}");
        gsub(/_/, "\\\\_");
        gsub(/#/, "\\\\#");
        gsub(/\$/, "\\\\$");
        gsub(/&/, "\\\\&");
        gsub(/%/, "\\\\%");
        gsub(/\^/, "\\\\textasciicircum{}");
        gsub(/~/, "\\\\textasciitilde{}");
        print
    }'
}

# Replace placeholders in LaTeX file (using @ as delimiter to avoid conflicts)
echo "🔄 Updating placeholders..."
sed "s@PLACEHOLDER_COMMIT_HASH@${COMMIT_SHORT}@g" ${LATEX_FILE} | \
sed "s@PLACEHOLDER_COMMIT_DATE@${COMMIT_DATE}@g" | \
sed "s@PLACEHOLDER_COMMIT_AUTHOR@${COMMIT_AUTHOR}@g" | \
sed "s@PLACEHOLDER_COMMIT_MESSAGE@${COMMIT_MESSAGE}@g" > ${TEMP_FILE}

# Collect documentation content
echo "📚 Collecting documentation content..."
echo "" > ${DOC_SECTION_FILE}

# Collect all markdown documentation files
for doc_file in docs/*.md README.md; do
    if [ -f "$doc_file" ] && [ -s "$doc_file" ]; then
        echo "  Processing: $doc_file"
        FILE_NAME=$(basename "$doc_file" .md | sed 's/_/\\_/g' | sed 's/-/ /g')
        
        echo "\\subsection{${FILE_NAME}}" >> ${DOC_SECTION_FILE}
        echo "" >> ${DOC_SECTION_FILE}
        echo "\\begin{lstlisting}[breaklines=true,breakatwhitespace=true]" >> ${DOC_SECTION_FILE}
        
        # Read file content and filter out problematic Unicode characters
        # Use Python for reliable Unicode filtering
        python3 << PYTHON_FILTER
import sys
import re

# Read the file
with open('$doc_file', 'r', encoding='utf-8', errors='ignore') as f:
    content = f.read()

# Remove box-drawing characters (common in markdown)
box_chars = r'[┌┐└┘├┤┬┴┼─│╔╗╚╝╠╣╦╩╬═║━┃┏┓┗┛┣┫┳┻╋]'
content = re.sub(box_chars, ' ', content)

# Remove emojis and other problematic Unicode
# Keep only ASCII printable characters and common whitespace
filtered_content = ''
for char in content:
    if ord(char) < 128 and (char.isprintable() or char.isspace()):
        filtered_content += char
    else:
        filtered_content += ' '

# Clean up multiple spaces but preserve line breaks
lines = filtered_content.split('\n')
cleaned_lines = []
for line in lines:
    cleaned_line = re.sub(r' +', ' ', line)
    cleaned_lines.append(cleaned_line)
content = '\n'.join(cleaned_lines)

sys.stdout.write(content)
PYTHON_FILTER
        >> ${DOC_SECTION_FILE}
        
        echo "\\end{lstlisting}" >> ${DOC_SECTION_FILE}
        echo "" >> ${DOC_SECTION_FILE}
        echo "\\newpage" >> ${DOC_SECTION_FILE}
        echo "" >> ${DOC_SECTION_FILE}
    fi
done

# Create commit changes section
echo "\\subsection{Changes in This Commit}" > ${CHANGES_SECTION_FILE}
echo "\\begin{itemize}" >> ${CHANGES_SECTION_FILE}
# Write commit changes line by line to avoid shell expansion issues
if git rev-parse HEAD~1 >/dev/null 2>&1; then
    git diff HEAD~1 HEAD --name-status | while IFS=$'\t' read -r status file; do
        # Escape LaTeX special characters in filename
        ESCAPED_FILE=$(echo "$file" | sed 's/\\/\\textbackslash{}/g' | sed 's/{/\\{/g' | sed 's/}/\\}/g' | sed 's/_/\\_/g' | sed 's/#/\\#/g' | sed 's/\$/\\\$/g' | sed 's/&/\\&/g' | sed 's/%/\\%/g')
        # Wrap status and filename in texttt to prevent math mode interpretation
        echo "\\item \\texttt{${status}} \\texttt{${ESCAPED_FILE}}" >> ${CHANGES_SECTION_FILE}
    done
else
    echo "\\item Initial commit" >> ${CHANGES_SECTION_FILE}
fi
echo "\\end{itemize}" >> ${CHANGES_SECTION_FILE}
echo "" >> ${CHANGES_SECTION_FILE}

# Use awk to replace placeholders (more reliable than sed for complex content)
awk -v doc_file="${DOC_SECTION_FILE}" -v changes_file="${CHANGES_SECTION_FILE}" '
BEGIN {
    # Read documentation content
    while ((getline line < doc_file) > 0) {
        doc_content = doc_content line "\n"
    }
    close(doc_file)
    
    # Read changes content
    while ((getline line < changes_file) > 0) {
        changes_content = changes_content line "\n"
    }
    close(changes_file)
}
/% PLACEHOLDER_DOCUMENTATION_CONTENT/ {
    print doc_content
    next
}
/% PLACEHOLDER_COMMIT_CHANGES/ {
    print changes_content
    next
}
{
    print
}
' ${TEMP_FILE} > ${LATEX_FILE}

# Clean up
rm -f ${TEMP_FILE} ${DOC_SECTION_FILE} ${CHANGES_SECTION_FILE}

echo "✅ LaTeX documentation updated successfully"
echo "   Commit Hash: ${COMMIT_SHORT}"
echo "   File: ${LATEX_FILE}"
