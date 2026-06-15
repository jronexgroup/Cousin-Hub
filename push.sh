#!/bin/bash
set -e

git add .

echo ""
read -p "Commit message: " msg

git commit -m "$msg"
git push

echo ""
echo "✅ Pushed successfully"
