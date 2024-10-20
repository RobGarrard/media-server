#!/bin/bash
#------------------------------------------------------------------------------#
# Startup script for media server
#
# This script installs Docker, pulls the Jellyfin Docker image, and runs the
# Jellyfin container.
#------------------------------------------------------------------------------#

# Update the package repository
sudo apt-get update -y

# Install Docker
sudo apt-get install -y docker.io

# Start Docker service
sudo systemctl start docker
sudo systemctl enable docker

# Pull the Jellyfin Docker image
sudo docker pull jellyfin/jellyfin


# Create config and cache directories
sudo mkdir -p /opt/jellyfin/config
sudo mkdir -p /opt/jellyfin/cache

# Create the media directory in the home directory
sudo mkdir -p /home/ubuntu/media
sudo mkdir -p /home/ubuntu/media/movies
sudo mkdir -p /home/ubuntu/media/tv_shows

# Run the Jellyfin container with EFS volume
sudo docker run -d \
    --name jellyfin \
    -p 8096:8096 \
    -v /opt/jellyfin/config:/config \
    -v /opt/jellyfin/cache:/cache \
    -v /home/ubuntu/media:/media \
    --restart unless-stopped \
    jellyfin/jellyfin