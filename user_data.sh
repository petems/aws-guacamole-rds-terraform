#!/bin/bash

# Update the system
yum update -y

# Install required packages
yum install -y docker wget mysql

# Start and enable Docker
systemctl start docker
systemctl enable docker

# Add ec2-user to docker group
usermod -a -G docker ec2-user

# Create Guacamole directories
mkdir -p /opt/guacamole
cd /tmp

# Create Guacamole configuration directory
mkdir -p /opt/guacamole

# Wait for RDS to be available
echo "Waiting for database to be available..."
while ! mysql -h ${db_host} -u ${db_username} -p${db_password} -e "SELECT 1" 2>/dev/null; do
    echo "Database not ready yet, waiting 30 seconds..."
    sleep 30
done

echo "Database is available, setting up schema..."

# Generate database schema
cd /opt/guacamole
docker run --rm guacamole/guacamole:latest /opt/guacamole/bin/initdb.sh --mysql > initdb.sql

# Apply database schema
mysql -h ${db_host} -u ${db_username} -p${db_password} ${db_name} < initdb.sql

# Create systemd service for guacd
cat > /etc/systemd/system/guacd.service << EOF
[Unit]
Description=Guacamole Daemon
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/docker run --name guacd --rm -d guacamole/guacd:latest
ExecStop=/usr/bin/docker stop guacd
ExecStopPost=/usr/bin/docker rm guacd
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Create systemd service for Guacamole
cat > /etc/systemd/system/guacamole.service << EOF
[Unit]
Description=Guacamole Web Application
After=guacd.service docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/docker run --name guacamole --rm -d \\
  --link guacd:guacd \\
  -e MYSQL_HOSTNAME=${db_host} \\
  -e MYSQL_DATABASE=${db_name} \\
  -e MYSQL_USERNAME=${db_username} \\
  -e MYSQL_PASSWORD=${db_password} \\
  -p 8080:8080 \\
  guacamole/guacamole:latest
ExecStop=/usr/bin/docker stop guacamole
ExecStopPost=/usr/bin/docker rm guacamole
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and enable services
systemctl daemon-reload
systemctl enable guacd.service
systemctl enable guacamole.service
systemctl start guacd.service
systemctl start guacamole.service

echo "Guacamole installation completed!"
echo "Access Guacamole at: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080/guacamole"
echo "Default credentials: guacadmin / guacadmin"