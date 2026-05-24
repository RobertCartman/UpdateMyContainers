#!/bin/bash

# Define the base directory
BASE_DIR="$HOME/my_docker_containers"

# Check if the base directory exists
if [ ! -d "$BASE_DIR" ]; then
    echo "Error: Directory '$BASE_DIR' does not exist."
    exit 1
fi

echo "Starting smart Docker Compose updates (Zero-Downtime Optimization)..."
echo "=========================================="

for dir in "$BASE_DIR"/*/; do
    [ -e "$dir" ] || continue
    folder_name=$(basename "$dir")
    
    echo ""
    echo "------------------------------------------"
    echo "Processing: $folder_name"
    echo "------------------------------------------"
    
    cd "$dir" || { echo "Failed to enter $dir"; continue; }
    
    if [ -f "docker-compose.yml" ] || [ -f "docker-compose.yaml" ]; then
        
        # 1. Check and save the running state first
        if docker compose ps --format json | grep -q '"State":"running"'; then
            was_running=true
            echo "--> Status: Container(s) are currently running."
        else
            was_running=false
            echo "--> Status: Container(s) are currently stopped."
        fi
        
        # 2. Pull the latest images safely in the background while containers run.
        # We capture the output to detect if an actual download happens.
        echo "--> Checking registry for updates..."
        pull_output=$(docker compose pull 2>&1)
        echo "$pull_output"
        
        # Check if the pull output contains phrases indicating a fresh download
        if echo "$pull_output" | grep -E -q "Downloaded newer image|Downloaded|Extracting|Pulling fs layer"; then
            image_updated=true
            echo "--> Result: A newer image version was found and downloaded."
        else
            image_updated=false
            echo "--> Result: Image is already up-to-date."
        fi
        
        # 3. Smart execution logic based on state and updates
        if [ "$image_updated" = true ]; then
            if [ "$was_running" = true ]; then
                echo "--> New image found. Cycling running container..."
                docker compose down
                docker compose up -d
                echo "Status: $folder_name successfully updated and restarted."
            else
                echo "--> New image found. Re-creating stopped container configuration..."
                docker compose down
                docker compose create
                echo "Status: $folder_name updated (left stopped as requested)."
            fi
        else
            # No update was found
            if [ "$was_running" = true ]; then
                echo "Status: $folder_name is already running the latest version. Skipping restart (Zero Downtime)."
            else
                echo "Status: $folder_name is up-to-date and remains stopped."
            fi
        fi
    else
        echo "Skipping: No docker-compose file found in '$folder_name'."
    fi
done

echo "Remove old / unused images..."
docker image prune -f

echo ""
echo "=========================================="
echo "All done! Smart Docker updates complete."
