#!/bin/bash

# Ensure we're on the main branch
git checkout main

# Restore missing files in main
mkdir -p dir1/dir2 dir3  # Ensure directories exist
touch dir1/dir2/foo      # Ensure foo exists
touch dir3/bar           # Ensure bar exists
touch dir3/bar_copy      # Ensure bar_copy exists

# Stage and commit the restored structure
git add .
git commit -m "Restore main branch structure"

# Create branch1 and switch to it
git checkout -b branch1

# Move foo from dir2 to dir1
git mv dir1/dir2/foo dir1/

# Remove empty dir2
rmdir dir1/dir2

# Remove bar_copy
rm -f dir3/bar_copy

# Create newfile1
touch newfile1

# Stage and commit changes for branch1
git add .
git commit -m "Modified structure for branch1"

# Switch back to main
git checkout main

# Create branch2 and switch to it
git checkout -b branch2

# Rename foo to foo_modified inside dir2
git mv dir1/dir2/foo dir1/dir2/foo_modified

# Remove bar and bar_copy (if exists) from dir3
rm -f dir3/bar dir3/bar_copy

# Create newfile2 inside dir3
mkdir -p dir1/dir3  # Ensure dir3 exists in the correct location
touch dir1/dir3/newfile2

# Stage and commit changes for branch2
git add .
git commit -m "Modified structure for branch2"

