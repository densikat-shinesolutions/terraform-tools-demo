#!/bin/bash

sudo apt-get update

# Install SQLITE3
sudo apt-get install -y sqlite3 unzip

# Make sure SSM agent is started
sudo snap start amazon-ssm-agent
sudo snap services amazon-ssm-agent

# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
