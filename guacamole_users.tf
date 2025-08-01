# Guacamole User Management
# This file manages additional Guacamole users via MySQL provider

# MySQL provider configuration for user management
terraform {
  required_providers {
    mysql = {
      source  = "petoju/mysql"
      version = "~> 3.0"
    }
  }
}

# MySQL provider
provider "mysql" {
  count    = var.manage_users_with_terraform ? 1 : 0
  endpoint = aws_db_instance.guacamole_db.endpoint
  username = var.db_username
  password = var.db_password
}

# Random salt generation for each user
resource "random_password" "user_salt" {
  for_each = var.manage_users_with_terraform ? var.guacamole_users : {}
  length   = 64
  special  = false
}

# Create Guacamole entities for users
resource "mysql_query" "create_user_entities" {
  for_each = var.manage_users_with_terraform ? var.guacamole_users : {}
  
  depends_on = [aws_instance.guacamole_server]
  
  create_sql = <<-EOF
    INSERT IGNORE INTO guacamole_entity (name, type) 
    VALUES ('${each.key}', 'USER');
  EOF
  
  delete_sql = <<-EOF
    DELETE FROM guacamole_user_permission WHERE entity_id = (SELECT entity_id FROM guacamole_entity WHERE name = '${each.key}');
    DELETE FROM guacamole_system_permission WHERE entity_id = (SELECT entity_id FROM guacamole_entity WHERE name = '${each.key}');
    DELETE FROM guacamole_user WHERE entity_id = (SELECT entity_id FROM guacamole_entity WHERE name = '${each.key}');
    DELETE FROM guacamole_entity WHERE name = '${each.key}' AND type = 'USER';
  EOF
}

# Create Guacamole user records with hashed passwords
resource "mysql_query" "create_user_records" {
  for_each = var.manage_users_with_terraform ? var.guacamole_users : {}
  
  depends_on = [mysql_query.create_user_entities]
  
  create_sql = <<-EOF
    SET @salt = UNHEX('${random_password.user_salt[each.key].result}');
    INSERT IGNORE INTO guacamole_user (entity_id, password_hash, password_salt, password_date, full_name, email_address)
    SELECT 
        entity_id,
        UNHEX(SHA2(CONCAT('${each.value.password}', '${random_password.user_salt[each.key].result}'), 256)),
        @salt,
        NOW(),
        '${each.value.full_name}',
        '${each.value.email}'
    FROM guacamole_entity 
    WHERE name = '${each.key}' AND type = 'USER';
  EOF
  
  delete_sql = <<-EOF
    DELETE FROM guacamole_user WHERE entity_id = (SELECT entity_id FROM guacamole_entity WHERE name = '${each.key}');
  EOF
}

# Grant system permissions to users
resource "mysql_query" "grant_user_permissions" {
  for_each = var.manage_users_with_terraform ? var.guacamole_users : {}
  
  depends_on = [mysql_query.create_user_records]
  
  create_sql = <<-EOF
    INSERT IGNORE INTO guacamole_system_permission (entity_id, permission)
    SELECT entity_id, permission
    FROM (
      ${join(" UNION ", [for perm in each.value.permissions : "SELECT '${each.key}' AS username, '${perm}' AS permission"])}
    ) permissions
    JOIN guacamole_entity ON permissions.username = guacamole_entity.name AND guacamole_entity.type = 'USER';
  EOF
  
  delete_sql = <<-EOF
    DELETE FROM guacamole_system_permission WHERE entity_id = (SELECT entity_id FROM guacamole_entity WHERE name = '${each.key}');
  EOF
}

# Grant self-administration permissions to users
resource "mysql_query" "grant_self_permissions" {
  for_each = var.manage_users_with_terraform ? var.guacamole_users : {}
  
  depends_on = [mysql_query.grant_user_permissions]
  
  create_sql = <<-EOF
    INSERT IGNORE INTO guacamole_user_permission (entity_id, affected_user_id, permission)
    SELECT guacamole_entity.entity_id, guacamole_user.user_id, permission
    FROM (
        SELECT '${each.key}' AS username, 'READ' AS permission
        UNION SELECT '${each.key}' AS username, 'UPDATE' AS permission
    ) permissions
    JOIN guacamole_entity ON permissions.username = guacamole_entity.name AND guacamole_entity.type = 'USER'
    JOIN guacamole_user ON guacamole_user.entity_id = guacamole_entity.entity_id;
  EOF
  
  delete_sql = <<-EOF
    DELETE FROM guacamole_user_permission WHERE entity_id = (SELECT entity_id FROM guacamole_entity WHERE name = '${each.key}');
  EOF
}