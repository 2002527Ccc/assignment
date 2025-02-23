git fetch --all
git checkout branch2
git checkout -b branch3 origin/branch3
git merge branch3
git commit -m "Merged branch3 into branch2 with conflict resolution"
git branch -d branch3
git push origin --delete branch3
git push origin branch2
