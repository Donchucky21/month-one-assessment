#!/bin/bash
# Installs Apache and writes a simple page showing the instance-id
yum update -y
yum install -y httpd
systemctl enable httpd
systemctl start httpd

INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
cat > /var/www/html/index.html <<EOF
<html>
  <head><title>TechCorp Web</title></head>
  <body>
    <h1>TechCorp Web Server</h1>
    <p>Instance ID: ${INSTANCE_ID}</p>
    <p>Served via ALB</p>
  </body>
</html>
EOF

