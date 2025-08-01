#!/bin/bash
# Bulk Guacamole User Creation Script
# Usage: ./bulk_add_users.sh <db_endpoint> <db_username> <db_password> <db_name>

set -e

DB_ENDPOINT="$1"
DB_USERNAME="$2"
DB_PASSWORD="$3"
DB_NAME="$4"

if [ $# -ne 4 ]; then
    echo "Usage: $0 <db_endpoint> <db_username> <db_password> <db_name>"
    echo "Example: $0 guacamole-mysql.xyz.rds.amazonaws.com guacamole mypassword guacamole_db"
    exit 1
fi

# Check if mysql client is available
if ! command -v mysql &> /dev/null; then
    echo "Error: mysql client is not installed"
    exit 1
fi

# Test database connection
echo "Testing database connection..."
mysql -h "$DB_ENDPOINT" -u "$DB_USERNAME" -p"$DB_PASSWORD" "$DB_NAME" -e "SELECT 1;" > /dev/null
echo "✅ Database connection successful"

# Function to create a user
create_user() {
    local username="$1"
    local password="$2"
    local full_name="$3"
    local email="$4"
    local permissions="$5"
    
    echo "Creating user: $username"
    
    # Generate SQL for this user
    cat > /tmp/create_user_${username}.sql << EOF
-- Create user: $username
SET @username = '$username';
SET @password = '$password';
SET @full_name = '$full_name';
SET @email = '$email';
SET @salt = UNHEX(SHA2(UUID(), 256));

-- Create entity
INSERT IGNORE INTO guacamole_entity (name, type) VALUES (@username, 'USER');

-- Create user with hashed password
INSERT IGNORE INTO guacamole_user (entity_id, password_hash, password_salt, password_date, full_name, email_address)
SELECT
    entity_id,
    UNHEX(SHA2(CONCAT(@password, HEX(@salt)), 256)),
    @salt,
    NOW(),
    @full_name,
    @email
FROM guacamole_entity WHERE name = @username AND type = 'USER';

-- Grant system permissions
INSERT IGNORE INTO guacamole_system_permission (entity_id, permission)
SELECT entity_id, permission
FROM (
    SELECT @username AS username, 'CREATE_CONNECTION' AS permission
    UNION SELECT @username AS username, 'CREATE_CONNECTION_GROUP' AS permission
) permissions
JOIN guacamole_entity ON permissions.username = guacamole_entity.name AND guacamole_entity.type = 'USER';

-- Grant self-administration permissions
INSERT IGNORE INTO guacamole_user_permission (entity_id, affected_user_id, permission)
SELECT guacamole_entity.entity_id, guacamole_user.user_id, permission
FROM (
    SELECT @username AS username, 'READ' AS permission
    UNION SELECT @username AS username, 'UPDATE' AS permission
) permissions
JOIN guacamole_entity ON permissions.username = guacamole_entity.name AND guacamole_entity.type = 'USER'
JOIN guacamole_user ON guacamole_user.entity_id = guacamole_entity.entity_id;
EOF

    # Execute SQL
    mysql -h "$DB_ENDPOINT" -u "$DB_USERNAME" -p"$DB_PASSWORD" "$DB_NAME" < /tmp/create_user_${username}.sql
    rm /tmp/create_user_${username}.sql
    echo "✅ User $username created successfully"
}

# Example users - modify this section for your needs
echo "Creating example users..."

create_user "john.doe" "SecurePassword123!" "John Doe" "john.doe@company.com"
create_user "jane.smith" "AnotherSecure456!" "Jane Smith" "jane.smith@company.com"
create_user "bob.wilson" "ThirdPassword789!" "Bob Wilson" "bob.wilson@company.com"

echo ""
echo "✅ All users created successfully!"
echo ""
echo "📋 User Summary:"
mysql -h "$DB_ENDPOINT" -u "$DB_USERNAME" -p"$DB_PASSWORD" "$DB_NAME" << 'EOF'
SELECT 
    e.name as username,
    u.full_name,
    u.email_address,
    u.password_date as created_date
FROM guacamole_user u
JOIN guacamole_entity e ON u.entity_id = e.entity_id
WHERE e.type = 'USER'
ORDER BY u.password_date DESC;
EOF