resource "aws_db_instance" "postgres" {
  identifier = "${local.name_prefix}-postgres"

  engine         = "postgres"
  engine_version = var.db_engine_version

  instance_class    = var.db_instance_class
  allocated_storage = var.db_allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username
  port     = var.db_port

  db_subnet_group_name = aws_db_subnet_group.main.name

  vpc_security_group_ids = [
    var.database_access_security_group_id
  ]

  publicly_accessible = false
  multi_az            = false

  backup_retention_period  = 0
  deletion_protection      = false
  skip_final_snapshot      = true
  delete_automated_backups = true

  auto_minor_version_upgrade = true
  apply_immediately          = true

  manage_master_user_password = true

  copy_tags_to_snapshot = true

  tags = {
    Name = "${local.name_prefix}-postgres"
  }
}