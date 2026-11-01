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

  validation {
    condition     = can(regex("^vpc-[0-9a-f]+$", var.vpc_id))
    error_message = "vpc_id deve possuir formato vpc-xxxxxxxx."
  }
}

variable "subnet_ids" {
  description = "IDs das subnets utilizadas pelo RDS"
  type        = list(string)

  validation {
    condition = (
      length(var.subnet_ids) >= 2 &&
      alltrue([
        for subnet_id in var.subnet_ids :
        can(regex("^subnet-[0-9a-f]+$", subnet_id))
      ])
    )

    error_message = "subnet_ids deve conter pelo menos duas subnets AWS validas."
  }
}

variable "database_access_security_group_id" {
  description = "Security Group associado ao RDS PostgreSQL"
  type        = string

  validation {
    condition = can(
      regex(
        "^sg-[0-9a-f]+$",
        var.database_access_security_group_id
      )
    )

    error_message = "database_access_security_group_id deve possuir formato sg-xxxxxxxx."
  }
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