# LaTeX Master Documentation

This directory contains the master LaTeX documentation file that is automatically updated and compiled on each commit.

## Overview

The `master_documentation.tex` file is a comprehensive documentation file that includes:
- Cover page with current commit hash
- Table of contents
- All project documentation
- Commit history and changes
- Automatically compiled to PDF

## How It Works

1. **On Each Commit**: The GitHub Actions workflow automatically:
   - Updates the commit hash in the cover page
   - Collects all documentation files
   - Appends new documentation from the latest commit
   - Compiles the LaTeX file to PDF
   - Commits the updated `.tex` and `.pdf` files back to the repository

2. **Documentation Collection**: The script collects:
   - All markdown files from `docs/` directory
   - `README.md` from the root
   - Converts markdown to LaTeX format
   - Includes commit changes

3. **PDF Generation**: The PDF is:
   - Compiled using `pdflatex`
   - Saved as `master_documentation.pdf`
   - Uploaded as a GitHub Actions artifact
   - Committed back to the repository

## Files

- `master_documentation.tex` - Main LaTeX source file
- `master_documentation.pdf` - Compiled PDF (generated automatically)
- `*.aux`, `*.log`, `*.toc`, etc. - LaTeX auxiliary files (ignored by git)

## Manual Compilation

To compile manually:

```bash
cd documentation
pdflatex master_documentation.tex
pdflatex master_documentation.tex  # Run twice for TOC
```

## Requirements

- LaTeX distribution (texlive-latex-base, texlive-latex-extra)
- Required packages are automatically installed in the GitHub Actions workflow

## Versioning

The documentation version is tied to the commit hash displayed on the cover page. Each commit updates the cover page with the new commit hash and appends any new documentation.

