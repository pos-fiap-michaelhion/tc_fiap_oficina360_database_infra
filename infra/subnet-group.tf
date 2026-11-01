resource "aws_db_subnet_group" "main" {
  name        = "oficina360-db-subnets"
  description = "Subnets utilizadas pelo RDS PostgreSQL"
  subnet_ids  = var.subnet_ids

  tags = {
    Name        = "oficina360-db-subnets"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}