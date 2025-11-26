#!/bin/bash
# Installs Postgres (Postgres 12 from Amazon Linux 2 repo) and starts it
yum update -y
amazon-linux-extras enable postgresql12
yum install -y postgresql-server postgresql-contrib

# initialize DB and enable remote connections (listen on all)
postgresql-setup --initdb
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" /var/lib/pgsql/data/postgresql.conf
# Allow password auth from the web SG range; for simplicity we allow local connections only here.
cat >> /var/lib/pgsql/data/pg_hba.conf <<EOF
# Allow local md5
host    all             all             10.0.3.0/24         md5
host    all             all             10.0.4.0/24         md5
EOF

systemctl enable postgresql
systemctl start postgresql

# create a user and database for testing (username: techcorp, password: password123)
sudo -u postgres psql -c "CREATE USER techcorp WITH PASSWORD 'password123';"
sudo -u postgres psql -c "CREATE DATABASE techcorp_db OWNER techcorp;"

