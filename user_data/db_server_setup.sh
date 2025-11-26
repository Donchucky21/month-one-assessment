#!/bin/bash
# Installs Postgres (Postgres 12 from Amazon Linux 2 repo) and starts it

yum update -y
amazon-linux-extras enable postgresql12
yum install -y postgresql-server postgresql-contrib

# Initialize DB and enable remote connections (listen on all)
postgresql-setup --initdb
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" /var/lib/pgsql/data/postgresql.conf

# Allow password auth from private subnets
cat >> /var/lib/pgsql/data/pg_hba.conf <<EOF
host    all             all             10.0.3.0/24         md5
host    all             all             10.0.4.0/24         md5
EOF

systemctl enable postgresql
systemctl start postgresql

# Create a user and database for testing
sudo -u postgres psql -c "CREATE USER techcorp WITH PASSWORD 'password123';"
sudo -u postgres psql -c "CREATE DATABASE techcorp_db OWNER techcorp;"

# -------------------------------
# Enable SSH password login
# -------------------------------
# Set Linux password for ec2-user
echo "ec2-user:Password123" | sudo chpasswd

# Enable password authentication in SSH
sudo sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Restart SSH service to apply changes
sudo systemctl restart sshd
