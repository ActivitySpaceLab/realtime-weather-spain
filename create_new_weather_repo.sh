#!/bin/bash

# create_new_weather_repo.sh
# Script to create a new weather forecast repository from current branch

echo "=== CREATING NEW WEATHER DATA COLLECTOR REPOSITORY ==="

# 1. Get current location
CURRENT_DIR=$(pwd)
REPO_NAME="weather-data-collector-spain"

# 2. Navigate to parent directory
cd ..

# 3. Create new directory for the new repo
echo "Creating new repository directory: $REPO_NAME"
mkdir -p $REPO_NAME
cd $REPO_NAME

# 4. Initialize new git repository
echo "Initializing new git repository..."
git init

# 5. Copy files from current repo (excluding .git)
echo "Copying files from original repository..."
rsync -av --exclude='.git' --exclude='*.log' --exclude='tmp/' "$CURRENT_DIR/" ./

# 6. Create initial commit
echo "Creating initial commit..."
git add .
git commit -m "Initial commit: Spain weather data collection with expanded metrics and API key rotation

Features:
- Multiple AEMET API keys with automatic rotation
- Expanded variable collection (7 safe variables)
- Municipal forecast collection for all 8,129 Spanish municipalities  
- Robust error handling and rate limiting
- Comprehensive documentation

Based on feature/expanded-metrics branch from realtime-weather-spain"

# 7. Set up remote (you'll need to create the GitHub repo first)
echo ""
echo "Repository created successfully at: $(pwd)"
echo ""
echo "Next steps:"
echo "1. Create a new repository on GitHub named '$REPO_NAME'"
echo "2. Run: git remote add origin https://github.com/YOUR_USERNAME/$REPO_NAME.git"
echo "3. Run: git branch -M main"
echo "4. Run: git push -u origin main"
echo ""
echo "Your new repository is ready!"
