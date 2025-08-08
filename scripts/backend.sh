#!/bin/bash

# Update system and install Docker
sudo apt update -y
sudo apt install -y docker.io

# Start and enable Docker
sudo systemctl start docker
sudo systemctl enable docker

# Pull backend container from DockerHub (replace with your actual repo name)
sudo docker pull sbk31/backend-app

# Run container (port 5000 exposed)
sudo docker run -d -p 5000:5000 sbk31/backend-app
