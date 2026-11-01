variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "lab"
}

variable "vpc_id" {
  description = "Existing VPC ID"
  type        = string
}

variable "subnet_a_id" {
  description = "Existing subnet in us-east-1a"
  type        = string
}

variable "subnet_b_id" {
  description = "Existing subnet in us-east-1b"
  type        = string
  default     = "subnet-0d68164f504b7edbc"
}

variable "default_security_group_id" {
  description = "Existing default VPC security group"
  type        = string
}

variable "db_name" {
  description = "Initial database name"
  type        = string
  default     = "oficina360"
}

variable "db_username" {
  description = "RDS master username"
  type        = string
  default     = "oficina360"
}

variable "project_name" {
  description = "Nome do projeto"
  type        = string
  default     = "oficina360-db"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t4g.micro"
}

variable "db_engine_version" {
  description = "PostgreSQL major version"
  type        = string
  default     = "16"
}

variable "db_port" {
  description = "PostgreSQL port"
  type        = number
  default     = 5432
}

variable "db_allocated_storage" {
  description = "RDS storage in GiB"
  type        = number
  default     = 20
}