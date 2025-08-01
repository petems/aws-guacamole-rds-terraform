-- Guacamole User Creation Script Template
-- Usage: Replace variables and run against your Guacamole MySQL database

-- Available permissions:
-- System: CREATE_CONNECTION, CREATE_CONNECTION_GROUP, CREATE_SHARING_PROFILE, CREATE_USER, CREATE_USER_GROUP, ADMINISTER
-- User: READ, UPDATE, DELETE, ADMINISTER

-- Example: Create a user named 'john.doe'
SET @username = 'john.doe';
SET @password = 'SecurePassword123!';
SET @full_name = 'John Doe';
SET @email = 'john.doe@company.com';

-- Generate random salt
SET @salt = UNHEX(SHA2(UUID(), 256));

-- Create entity
INSERT INTO guacamole_entity (name, type) VALUES (@username, 'USER');

-- Create user with hashed password
INSERT INTO guacamole_user (entity_id, password_hash, password_salt, password_date, full_name, email_address)
SELECT
    entity_id,
    UNHEX(SHA2(CONCAT(@password, HEX(@salt)), 256)),
    @salt,
    NOW(),
    @full_name,
    @email
FROM guacamole_entity WHERE name = @username AND type = 'USER';

-- Grant system permissions (choose which ones to include)
INSERT INTO guacamole_system_permission (entity_id, permission)
SELECT entity_id, permission
FROM (
    SELECT @username AS username, 'CREATE_CONNECTION' AS permission
    UNION SELECT @username AS username, 'CREATE_CONNECTION_GROUP' AS permission
    -- UNION SELECT @username AS username, 'CREATE_USER' AS permission  -- Uncomment for user admin
    -- UNION SELECT @username AS username, 'ADMINISTER' AS permission     -- Uncomment for full admin
) permissions
JOIN guacamole_entity ON permissions.username = guacamole_entity.name AND guacamole_entity.type = 'USER';

-- Grant self-administration permissions
INSERT INTO guacamole_user_permission (entity_id, affected_user_id, permission)
SELECT guacamole_entity.entity_id, guacamole_user.user_id, permission
FROM (
    SELECT @username AS username, 'READ' AS permission
    UNION SELECT @username AS username, 'UPDATE' AS permission
) permissions
JOIN guacamole_entity ON permissions.username = guacamole_entity.name AND guacamole_entity.type = 'USER'
JOIN guacamole_user ON guacamole_user.entity_id = guacamole_entity.entity_id;

-- Verify user creation
SELECT u.user_id, e.name, u.full_name, u.email_address, u.password_date
FROM guacamole_user u
JOIN guacamole_entity e ON u.entity_id = e.entity_id
WHERE e.name = @username;