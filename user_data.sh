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

# Generate custom database schema with admin credentials
cd /opt/guacamole

# Get the standard Guacamole schema (tables only, no default user)
docker run --rm guacamole/guacamole:latest /opt/guacamole/bin/initdb.sh --mysql > base_schema.sql

# Remove the default admin user creation from the schema
# The standard schema includes lines that create guacadmin user - we'll filter those out
grep -v "guacadmin" base_schema.sql > clean_schema.sql

# Create our custom admin user addition
cat >> clean_schema.sql << EOF

-- Custom admin user creation with secure credentials
-- Generate a random salt using UUID and SHA2
SET @salt = UNHEX(SHA2(UUID(), 256));

-- Create the custom admin entity
INSERT INTO guacamole_entity (name, type) VALUES ('${admin_username}', 'USER');

-- Create the admin user with hashed password
INSERT INTO guacamole_user (entity_id, password_hash, password_salt, password_date)
SELECT
    entity_id,
    UNHEX(SHA2(CONCAT('${admin_password}', HEX(@salt)), 256)),
    @salt,
    NOW()
FROM guacamole_entity WHERE name = '${admin_username}' AND type = 'USER';

-- Grant all system permissions to the admin user
INSERT INTO guacamole_system_permission (entity_id, permission)
SELECT entity_id, permission
FROM (
    SELECT '${admin_username}' AS username, 'CREATE_CONNECTION' AS permission
    UNION SELECT '${admin_username}' AS username, 'CREATE_CONNECTION_GROUP' AS permission  
    UNION SELECT '${admin_username}' AS username, 'CREATE_SHARING_PROFILE' AS permission
    UNION SELECT '${admin_username}' AS username, 'CREATE_USER' AS permission
    UNION SELECT '${admin_username}' AS username, 'CREATE_USER_GROUP' AS permission
    UNION SELECT '${admin_username}' AS username, 'ADMINISTER' AS permission
) permissions
JOIN guacamole_entity ON permissions.username = guacamole_entity.name AND guacamole_entity.type = 'USER';

-- Grant self-administration permissions to the admin user
INSERT INTO guacamole_user_permission (entity_id, affected_user_id, permission)
SELECT guacamole_entity.entity_id, guacamole_user.user_id, permission
FROM (
    SELECT '${admin_username}' AS username, 'READ' AS permission
    UNION SELECT '${admin_username}' AS username, 'UPDATE' AS permission
    UNION SELECT '${admin_username}' AS username, 'ADMINISTER' AS permission
) permissions
JOIN guacamole_entity ON permissions.username = guacamole_entity.name AND guacamole_entity.type = 'USER'
JOIN guacamole_user ON guacamole_user.entity_id = guacamole_entity.entity_id;
EOF

# Use the clean schema with custom admin
cp clean_schema.sql initdb.sql

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
echo "Custom admin credentials: ${admin_username} / [password set in terraform.tfvars]"