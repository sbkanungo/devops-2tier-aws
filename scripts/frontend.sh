#!/bin/bash

# Update system and install Docker
sudo apt update -y
sudo apt install -y docker.io

# Start and enable Docker
sudo systemctl start docker
sudo systemctl enable docker

# Pull frontend container from DockerHub (replace with your actual repo name)
sudo docker pull your_dockerhub_username/frontend-app

# Run container (port 80 exposed)
sudo docker run -d -p 80:80 your_dockerhub_username/frontend-app
