-- Apache Guacamole Database Schema with Custom Admin User
-- This script creates the base schema and a custom admin user instead of the default guacadmin

-- Create the base tables (this replaces the standard initdb.sh output)
CREATE TABLE guacamole_entity (
    entity_id     integer NOT NULL AUTO_INCREMENT,
    name          varchar(128) NOT NULL,
    type          enum('USER', 'USER_GROUP') NOT NULL,
    PRIMARY KEY (entity_id),
    UNIQUE KEY guacamole_entity_name_scope (type, name)
);

CREATE TABLE guacamole_user (
    user_id       integer NOT NULL AUTO_INCREMENT,
    entity_id     integer NOT NULL,
    password_hash binary(32),
    password_salt binary(32),
    password_date datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
    disabled      boolean NOT NULL DEFAULT 0,
    expired       boolean NOT NULL DEFAULT 0,
    access_window_start time,
    access_window_end   time,
    valid_from    date,
    valid_until   date,
    timezone      varchar(64),
    full_name     varchar(256),
    email_address varchar(256),
    organization  varchar(256),
    organizational_role varchar(256),
    PRIMARY KEY (user_id),
    UNIQUE KEY guacamole_user_single_entity (entity_id),
    CONSTRAINT guacamole_user_entity FOREIGN KEY (entity_id) REFERENCES guacamole_entity (entity_id) ON DELETE CASCADE
);

CREATE TABLE guacamole_user_group (
    user_group_id integer NOT NULL AUTO_INCREMENT,
    entity_id     integer NOT NULL,
    disabled      boolean NOT NULL DEFAULT 0,
    PRIMARY KEY (user_group_id),
    UNIQUE KEY guacamole_user_group_single_entity (entity_id),
    CONSTRAINT guacamole_user_group_entity FOREIGN KEY (entity_id) REFERENCES guacamole_entity (entity_id) ON DELETE CASCADE
);

CREATE TABLE guacamole_user_group_member (
    user_group_id integer NOT NULL,
    member_entity_id integer NOT NULL,
    PRIMARY KEY (user_group_id, member_entity_id),
    CONSTRAINT guacamole_user_group_member_parent_id FOREIGN KEY (user_group_id) REFERENCES guacamole_user_group (user_group_id) ON DELETE CASCADE,
    CONSTRAINT guacamole_user_group_member_entity_id FOREIGN KEY (member_entity_id) REFERENCES guacamole_entity (entity_id) ON DELETE CASCADE
);

CREATE TABLE guacamole_connection_group (
    connection_group_id   integer NOT NULL AUTO_INCREMENT,
    parent_id             integer,
    connection_group_name varchar(128) NOT NULL,
    type                  enum('ORGANIZATIONAL', 'BALANCING') NOT NULL DEFAULT 'ORGANIZATIONAL',
    max_connections       integer,
    max_connections_per_user integer,
    enable_session_affinity boolean NOT NULL DEFAULT 0,
    PRIMARY KEY (connection_group_id),
    UNIQUE KEY guacamole_connection_group_name_parent (connection_group_name, parent_id),
    CONSTRAINT guacamole_connection_group_parent FOREIGN KEY (parent_id) REFERENCES guacamole_connection_group (connection_group_id) ON DELETE CASCADE
);

CREATE TABLE guacamole_connection (
    connection_id       integer NOT NULL AUTO_INCREMENT,
    connection_name     varchar(128) NOT NULL,
    parent_id           integer,
    protocol            varchar(32) NOT NULL,
    proxy_port          integer,
    proxy_hostname      varchar(512),
    proxy_encryption_method enum('NONE', 'SSL'),
    max_connections     integer,
    max_connections_per_user integer,
    connection_weight   integer,
    failover_only       boolean NOT NULL DEFAULT 0,
    PRIMARY KEY (connection_id),
    UNIQUE KEY guacamole_connection_name_parent (connection_name, parent_id),
    CONSTRAINT guacamole_connection_parent FOREIGN KEY (parent_id) REFERENCES guacamole_connection_group (connection_group_id) ON DELETE CASCADE
);

CREATE TABLE guacamole_sharing_profile (
    sharing_profile_id    integer NOT NULL AUTO_INCREMENT,
    sharing_profile_name  varchar(128) NOT NULL,
    primary_connection_id integer NOT NULL,
    PRIMARY KEY (sharing_profile_id),
    UNIQUE KEY guacamole_sharing_profile_name_primary (sharing_profile_name, primary_connection_id),
    CONSTRAINT guacamole_sharing_profile_connection FOREIGN KEY (primary_connection_id) REFERENCES guacamole_connection (connection_id) ON DELETE CASCADE
);

-- Permission tables
CREATE TABLE guacamole_system_permission (
    entity_id  integer NOT NULL,
    permission enum('CREATE_CONNECTION', 'CREATE_CONNECTION_GROUP', 'CREATE_SHARING_PROFILE', 'CREATE_USER', 'CREATE_USER_GROUP', 'ADMINISTER') NOT NULL,
    PRIMARY KEY (entity_id, permission),
    CONSTRAINT guacamole_system_permission_entity FOREIGN KEY (entity_id) REFERENCES guacamole_entity (entity_id) ON DELETE CASCADE
);

CREATE TABLE guacamole_user_permission (
    entity_id         integer NOT NULL,
    affected_user_id  integer NOT NULL,
    permission        enum('READ', 'UPDATE', 'DELETE', 'ADMINISTER') NOT NULL,
    PRIMARY KEY (entity_id, affected_user_id, permission),
    CONSTRAINT guacamole_user_permission_entity FOREIGN KEY (entity_id) REFERENCES guacamole_entity (entity_id) ON DELETE CASCADE,
    CONSTRAINT guacamole_user_permission_affected_user FOREIGN KEY (affected_user_id) REFERENCES guacamole_user (user_id) ON DELETE CASCADE
);

CREATE TABLE guacamole_user_group_permission (
    entity_id              integer NOT NULL,
    affected_user_group_id integer NOT NULL,
    permission             enum('READ', 'UPDATE', 'DELETE', 'ADMINISTER') NOT NULL,
    PRIMARY KEY (entity_id, affected_user_group_id, permission),
    CONSTRAINT guacamole_user_group_permission_entity FOREIGN KEY (entity_id) REFERENCES guacamole_entity (entity_id) ON DELETE CASCADE,
    CONSTRAINT guacamole_user_group_permission_affected_user_group FOREIGN KEY (affected_user_group_id) REFERENCES guacamole_user_group (user_group_id) ON DELETE CASCADE
);

CREATE TABLE guacamole_connection_permission (
    entity_id                 integer NOT NULL,
    connection_id             integer NOT NULL,
    permission                enum('READ', 'UPDATE', 'DELETE', 'ADMINISTER') NOT NULL,
    PRIMARY KEY (entity_id, connection_id, permission),
    CONSTRAINT guacamole_connection_permission_entity FOREIGN KEY (entity_id) REFERENCES guacamole_entity (entity_id) ON DELETE CASCADE,
    CONSTRAINT guacamole_connection_permission_connection FOREIGN KEY (connection_id) REFERENCES guacamole_connection (connection_id) ON DELETE CASCADE
);

CREATE TABLE guacamole_connection_group_permission (
    entity_id                     integer NOT NULL,
    connection_group_id           integer NOT NULL,
    permission                    enum('READ', 'UPDATE', 'DELETE', 'ADMINISTER') NOT NULL,
    PRIMARY KEY (entity_id, connection_group_id, permission),
    CONSTRAINT guacamole_connection_group_permission_entity FOREIGN KEY (entity_id) REFERENCES guacamole_entity (entity_id) ON DELETE CASCADE,
    CONSTRAINT guacamole_connection_group_permission_connection_group FOREIGN KEY (connection_group_id) REFERENCES guacamole_connection_group (connection_group_id) ON DELETE CASCADE
);

CREATE TABLE guacamole_sharing_profile_permission (
    entity_id                   integer NOT NULL,
    sharing_profile_id          integer NOT NULL,
    permission                  enum('READ', 'UPDATE', 'DELETE', 'ADMINISTER') NOT NULL,
    PRIMARY KEY (entity_id, sharing_profile_id, permission),
    CONSTRAINT guacamole_sharing_profile_permission_entity FOREIGN KEY (entity_id) REFERENCES guacamole_entity (entity_id) ON DELETE CASCADE,
    CONSTRAINT guacamole_sharing_profile_permission_sharing_profile FOREIGN KEY (sharing_profile_id) REFERENCES guacamole_sharing_profile (sharing_profile_id) ON DELETE CASCADE
);

-- Parameter and attribute tables
CREATE TABLE guacamole_connection_parameter (
    connection_id   integer NOT NULL,
    parameter_name  varchar(128) NOT NULL,
    parameter_value varchar(4096),
    PRIMARY KEY (connection_id, parameter_name),
    CONSTRAINT guacamole_connection_parameter_connection FOREIGN KEY (connection_id) REFERENCES guacamole_connection (connection_id) ON DELETE CASCADE
);

CREATE TABLE guacamole_sharing_profile_parameter (
    sharing_profile_id integer NOT NULL,
    parameter_name     varchar(128) NOT NULL,
    parameter_value    varchar(4096),
    PRIMARY KEY (sharing_profile_id, parameter_name),
    CONSTRAINT guacamole_sharing_profile_parameter_sharing_profile FOREIGN KEY (sharing_profile_id) REFERENCES guacamole_sharing_profile (sharing_profile_id) ON DELETE CASCADE
);

CREATE TABLE guacamole_user_attribute (
    user_id         integer NOT NULL,
    attribute_name  varchar(128) NOT NULL,
    attribute_value varchar(4096),
    PRIMARY KEY (user_id, attribute_name),
    CONSTRAINT guacamole_user_attribute_user FOREIGN KEY (user_id) REFERENCES guacamole_user (user_id) ON DELETE CASCADE
);

CREATE TABLE guacamole_user_group_attribute (
    user_group_id   integer NOT NULL,
    attribute_name  varchar(128) NOT NULL,
    attribute_value varchar(4096),
    PRIMARY KEY (user_group_id, attribute_name),
    CONSTRAINT guacamole_user_group_attribute_user_group FOREIGN KEY (user_group_id) REFERENCES guacamole_user_group (user_group_id) ON DELETE CASCADE
);

CREATE TABLE guacamole_connection_attribute (
    connection_id   integer NOT NULL,
    attribute_name  varchar(128) NOT NULL,
    attribute_value varchar(4096),
    PRIMARY KEY (connection_id, attribute_name),
    CONSTRAINT guacamole_connection_attribute_connection FOREIGN KEY (connection_id) REFERENCES guacamole_connection (connection_id) ON DELETE CASCADE
);

CREATE TABLE guacamole_connection_group_attribute (
    connection_group_id integer NOT NULL,
    attribute_name      varchar(128) NOT NULL,
    attribute_value     varchar(4096),
    PRIMARY KEY (connection_group_id, attribute_name),
    CONSTRAINT guacamole_connection_group_attribute_connection_group FOREIGN KEY (connection_group_id) REFERENCES guacamole_connection_group (connection_group_id) ON DELETE CASCADE
);

CREATE TABLE guacamole_sharing_profile_attribute (
    sharing_profile_id integer NOT NULL,
    attribute_name     varchar(128) NOT NULL,
    attribute_value    varchar(4096),
    PRIMARY KEY (sharing_profile_id, attribute_name),
    CONSTRAINT guacamole_sharing_profile_attribute_sharing_profile FOREIGN KEY (sharing_profile_id) REFERENCES guacamole_sharing_profile (sharing_profile_id) ON DELETE CASCADE
);

-- History tables
CREATE TABLE guacamole_connection_history (
    history_id           integer NOT NULL AUTO_INCREMENT,
    user_id              integer,
    username             varchar(128) NOT NULL,
    remote_host          varchar(256),
    connection_id        integer,
    connection_name      varchar(128) NOT NULL,
    sharing_profile_id   integer,
    sharing_profile_name varchar(128),
    start_date           datetime NOT NULL,
    end_date             datetime,
    PRIMARY KEY (history_id),
    KEY guacamole_connection_history_user_id (user_id),
    KEY guacamole_connection_history_connection_id (connection_id),
    KEY guacamole_connection_history_sharing_profile_id (sharing_profile_id),
    KEY guacamole_connection_history_start_date (start_date),
    KEY guacamole_connection_history_end_date (end_date),
    KEY guacamole_connection_history_connection_id_start_date (connection_id, start_date),
    CONSTRAINT guacamole_connection_history_user FOREIGN KEY (user_id) REFERENCES guacamole_user (user_id) ON DELETE SET NULL,
    CONSTRAINT guacamole_connection_history_connection FOREIGN KEY (connection_id) REFERENCES guacamole_connection (connection_id) ON DELETE SET NULL,
    CONSTRAINT guacamole_connection_history_sharing_profile FOREIGN KEY (sharing_profile_id) REFERENCES guacamole_sharing_profile (sharing_profile_id) ON DELETE SET NULL
);

CREATE TABLE guacamole_user_history (
    history_id           integer NOT NULL AUTO_INCREMENT,
    user_id              integer,
    username             varchar(128) NOT NULL,
    remote_host          varchar(256),
    start_date           datetime NOT NULL,
    end_date             datetime,
    PRIMARY KEY (history_id),
    KEY guacamole_user_history_user_id (user_id),
    KEY guacamole_user_history_start_date (start_date),
    KEY guacamole_user_history_end_date (end_date),
    KEY guacamole_user_history_user_id_start_date (user_id, start_date),
    CONSTRAINT guacamole_user_history_user FOREIGN KEY (user_id) REFERENCES guacamole_user (user_id) ON DELETE SET NULL
);

CREATE TABLE guacamole_user_password_history (
    password_history_id integer NOT NULL AUTO_INCREMENT,
    user_id             integer NOT NULL,
    password_hash       binary(32) NOT NULL,
    password_salt       binary(32),
    password_date       datetime NOT NULL,
    PRIMARY KEY (password_history_id),
    CONSTRAINT guacamole_user_password_history_user FOREIGN KEY (user_id) REFERENCES guacamole_user (user_id) ON DELETE CASCADE
);

-- Create custom admin user with provided credentials
-- Generate a random salt using UUID and SHA2
SET @salt = UNHEX(SHA2(UUID(), 256));

-- Create the admin entity
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