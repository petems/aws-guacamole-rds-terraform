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

# Download Guacamole JDBC authentication extension
mkdir -p /opt/guacamole/extensions
mkdir -p /opt/guacamole/lib
cd /tmp

# Download Guacamole version 1.5.4 (latest stable)
GUACAMOLE_VERSION="1.5.4"
wget "https://downloads.apache.org/guacamole/$GUACAMOLE_VERSION/binary/guacamole-$GUACAMOLE_VERSION.war"
wget "https://downloads.apache.org/guacamole/$GUACAMOLE_VERSION/binary/guacamole-auth-jdbc-$GUACAMOLE_VERSION.tar.gz"

# Extract and setup JDBC authentication
tar -xzf guacamole-auth-jdbc-$GUACAMOLE_VERSION.tar.gz
cp guacamole-auth-jdbc-$GUACAMOLE_VERSION/mysql/guacamole-auth-jdbc-mysql-$GUACAMOLE_VERSION.jar /opt/guacamole/extensions/

# Download MySQL Connector/J
wget https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-j-8.2.0.tar.gz
tar -xzf mysql-connector-j-8.2.0.tar.gz
cp mysql-connector-j-8.2.0/mysql-connector-j-8.2.0.jar /opt/guacamole/lib/

# Create Guacamole configuration directory
mkdir -p /etc/guacamole

# Create guacamole.properties file
cat > /etc/guacamole/guacamole.properties << EOF
# MySQL properties
mysql-hostname: ${db_host}
mysql-port: 3306
mysql-database: ${db_name}
mysql-username: ${db_username}
mysql-password: ${db_password}

# Additional properties
mysql-default-max-connections-per-user: 0
mysql-default-max-group-connections-per-user: 0
EOF

# Wait for RDS to be available
echo "Waiting for database to be available..."
while ! mysql -h ${db_host} -u ${db_username} -p${db_password} -e "SELECT 1" 2>/dev/null; do
    echo "Database not ready yet, waiting 30 seconds..."
    sleep 30
done

echo "Database is available, setting up schema..."

# Download and run Guacamole database schema
cd /tmp
wget "https://raw.githubusercontent.com/apache/guacamole-client/master/extensions/guacamole-auth-jdbc/modules/guacamole-auth-jdbc-mysql/schema/001-create-schema.sql"
wget "https://raw.githubusercontent.com/apache/guacamole-client/master/extensions/guacamole-auth-jdbc/modules/guacamole-auth-jdbc-mysql/schema/002-create-admin-user.sql"

# Create database schema
mysql -h ${db_host} -u ${db_username} -p${db_password} ${db_name} < 001-create-schema.sql
mysql -h ${db_host} -u ${db_username} -p${db_password} ${db_name} < 002-create-admin-user.sql

# Run Guacamole daemon (guacd) container
docker run --name guacd -d -p 4822:4822 guacamole/guacd:1.5.4

# Run Guacamole web application container
docker run --name guacamole \
  --link guacd:guacd \
  -e GUACD_HOSTNAME=guacd \
  -e GUACD_PORT=4822 \
  -e MYSQL_HOSTNAME=${db_host} \
  -e MYSQL_PORT=3306 \
  -e MYSQL_DATABASE=${db_name} \
  -e MYSQL_USER=${db_username} \
  -e MYSQL_PASSWORD=${db_password} \
  -d -p 8080:8080 \
  -v /opt/guacamole/extensions:/opt/guacamole/extensions \
  -v /opt/guacamole/lib:/opt/guacamole/lib \
  -v /etc/guacamole:/etc/guacamole \
  guacamole/guacamole:1.5.4

# Create a simple nginx reverse proxy for HTTPS (optional)
yum install -y nginx
systemctl start nginx
systemctl enable nginx

# Create nginx configuration for Guacamole
cat > /etc/nginx/conf.d/guacamole.conf << EOF
server {
    listen 80;
    server_name _;
    
    location /guacamole/ {
        proxy_pass http://localhost:8080;
        proxy_buffering off;
        proxy_http_version 1.1;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$http_connection;
        proxy_cookie_path /guacamole/ /guacamole/;
        access_log off;
    }
    
    location / {
        return 301 /guacamole/;
    }
}
EOF

# Restart nginx
systemctl restart nginx

echo "Guacamole installation completed!"
echo "Access Guacamole at: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080/guacamole"
echo "Default credentials: guacadmin / guacadmin"