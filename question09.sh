#!/bin/bash

# Step 1: Create a new branch named branch1
git branch branch1

# Step 2: Switch to the new branch
git checkout branch1

# Step 3: Create a new file named file3
touch file3

# Step 4: Stage the new file
git add file3

# Step 5: Commit the new file with a message
git commit -m "Added file3 in branch1"

# Step 6: Push the new branch to remote repository
git push origin branch1
