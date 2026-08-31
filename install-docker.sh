#!/bin/bash
curl -fsSL https://get.docker.com -o get-docker.sh
sh ./get-docker.sh
usermod -aG docker ubuntu
apt install python3-venv python3-pip -y
