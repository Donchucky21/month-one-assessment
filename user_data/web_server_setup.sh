#!/bin/bash
# Install Apache Web Server and set up a sample page

# Update system and install Apache
yum update -y
yum install -y httpd

# Enable and start Apache
systemctl enable httpd
systemctl start httpd

# Create a simple HTML page with instance ID
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
echo "<h1>Web Server - Instance ID: $INSTANCE_ID</h1>" > /var/www/html/index.html

# -------------------------------
# Enable SSH password login
# -------------------------------
# Set Linux password for ec2-user
echo "ec2-user:Password123" | sudo chpasswd

# Enable password authentication in SSH
sudo sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Restart SSH service to apply changes
sudo systemctl restart sshd
