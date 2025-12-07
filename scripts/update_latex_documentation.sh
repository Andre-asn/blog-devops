#!/bin/bash
set -e

echo "📝 Updating LaTeX master documentation..."

# Configuration
LATEX_FILE="documentation/master_documentation.tex"
OUTPUT_DIR="documentation"
COMMIT_HASH=$(git rev-parse HEAD)
COMMIT_SHORT=$(git rev-parse --short=7 HEAD)
COMMIT_DATE=$(git log -1 --format=%ci HEAD | sed 's/ / /')
COMMIT_AUTHOR=$(git log -1 --format=%an HEAD | sed 's/_/\\_/g')
COMMIT_MESSAGE=$(git log -1 --format=%B HEAD | head -1 | sed 's/\\/\\\\/g' | sed 's/{/\\{/g' | sed 's/}/\\}/g' | sed 's/_/\\_/g' | sed 's/#/\\#/g')

# Get commit changes
echo "📋 Gathering commit changes..."
if git rev-parse HEAD~1 >/dev/null 2>&1; then
    COMMIT_CHANGES=$(git diff HEAD~1 HEAD --name-status | sed 's/^/\\item /' | sed 's/\\/\\\\/g' | sed 's/_/\\_/g')
else
    COMMIT_CHANGES="\\item Initial commit"
fi

# Create documentation directory if it doesn't exist
mkdir -p ${OUTPUT_DIR}

# Read existing LaTeX file or create new one
if [ ! -f "${LATEX_FILE}" ]; then
    echo "❌ LaTeX template file not found at ${LATEX_FILE}"
    exit 1
fi

# Create temporary file
TEMP_FILE=$(mktemp)

# Replace placeholders in LaTeX file
echo "🔄 Updating placeholders..."
sed "s|PLACEHOLDER_COMMIT_HASH|${COMMIT_SHORT}|g" ${LATEX_FILE} | \
sed "s|PLACEHOLDER_COMMIT_DATE|${COMMIT_DATE}|g" | \
sed "s|PLACEHOLDER_COMMIT_AUTHOR|${COMMIT_AUTHOR}|g" | \
sed "s|PLACEHOLDER_COMMIT_MESSAGE|${COMMIT_MESSAGE}|g" > ${TEMP_FILE}

# Collect documentation content
echo "📚 Collecting documentation content..."
DOC_CONTENT=""

# Function to escape LaTeX special characters
escape_latex() {
    echo "$1" | sed 's/\\/\\\\/g' | sed 's/{/\\{/g' | sed 's/}/\\}/g' | sed 's/_/\\_/g' | sed 's/#/\\#/g' | sed 's/\$/\\\$/g' | sed 's/&/\\&/g' | sed 's/%/\\%/g' | sed 's/\^/\\^{}/g' | sed 's/~/\~{} /g'
}

# Function to convert markdown headers to LaTeX sections
markdown_to_latex() {
    local content="$1"
    # Convert # Header to \subsection{Header}
    content=$(echo "$content" | sed 's/^# \(.*\)$/\\subsection{\1}/')
    # Convert ## Header to \subsubsection{Header}
    content=$(echo "$content" | sed 's/^## \(.*\)$/\\subsubsection{\1}/')
    # Convert ### Header to \paragraph{Header}
    content=$(echo "$content" | sed 's/^### \(.*\)$/\\paragraph{\1}/')
    # Convert **bold** to \textbf{bold}
    content=$(echo "$content" | sed 's/\*\*\([^*]*\)\*\*/\\textbf{\1}/g')
    # Convert `code` to \texttt{code}
    content=$(echo "$content" | sed 's/`\([^`]*\)`/\\texttt{\1}/g')
    echo "$content"
}

# Collect all markdown documentation files
for doc_file in docs/*.md README.md; do
    if [ -f "$doc_file" ] && [ -s "$doc_file" ]; then
        echo "  Processing: $doc_file"
        FILE_NAME=$(basename "$doc_file" .md | sed 's/_/\\_/g' | sed 's/-/ /g')
        DOC_CONTENT="${DOC_CONTENT}\n\\subsection{${FILE_NAME}}\n"
        
        # Convert markdown to LaTeX-friendly format
        CONVERTED_CONTENT=$(markdown_to_latex "$(cat "$doc_file")")
        ESCAPED_CONTENT=$(escape_latex "$CONVERTED_CONTENT")
        
        DOC_CONTENT="${DOC_CONTENT}${ESCAPED_CONTENT}\n\\newpage\n"
    fi
done

# Replace documentation placeholder
sed "s|% PLACEHOLDER_DOCUMENTATION_CONTENT|${DOC_CONTENT}|g" ${TEMP_FILE} > ${TEMP_FILE}.tmp
mv ${TEMP_FILE}.tmp ${TEMP_FILE}

# Add commit changes section
COMMIT_CHANGES_SECTION="\\subsection{Changes in This Commit}\n\\begin{itemize}\n${COMMIT_CHANGES}\n\\end{itemize}\n"
sed "s|% PLACEHOLDER_COMMIT_CHANGES|${COMMIT_CHANGES_SECTION}|g" ${TEMP_FILE} > ${LATEX_FILE}

# Clean up
rm -f ${TEMP_FILE}

echo "✅ LaTeX documentation updated successfully"
echo "   Commit Hash: ${COMMIT_SHORT}"
echo "   File: ${LATEX_FILE}"

