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

# Install dependencies for s3fs-fuse
sudo apt-get install -y automake build-essential libfuse-dev libcurl4-openssl-dev libxml2-dev mime-support

# Install s3fs-fuse
sudo apt-get install -y s3fs

# Create a directory to mount the S3 bucket
sudo mkdir -p /mnt/s3

# Mount the S3 bucket
sudo s3fs robs-media-server /mnt/s3 -o iam_role=auto -o allow_other


# Run the Jellyfin container with EFS volume
sudo docker run -d \
    --name jellyfin \
    -p 8096:8096 \
    -v /opt/jellyfin/config:/config \
    -v /opt/jellyfin/cache:/cache \
    -v /mnt/s3:/media \
    --restart unless-stopped \
    jellyfin/jellyfin