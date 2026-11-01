output "rds_identifier" {
  description = "RDS instance identifier"
  value       = aws_db_instance.postgres.identifier
}

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = aws_db_instance.postgres.address
}

output "rds_port" {
  description = "RDS PostgreSQL port"
  value       = aws_db_instance.postgres.port
}

output "database_name" {
  description = "Initial database name"
  value       = aws_db_instance.postgres.db_name
}

output "database_username" {
  description = "Master username"
  value       = aws_db_instance.postgres.username
}

output "rds_secret_arn" {
  description = "ARN of the RDS-managed master password secret"
  value       = aws_db_instance.postgres.master_user_secret[0].secret_arn
}

