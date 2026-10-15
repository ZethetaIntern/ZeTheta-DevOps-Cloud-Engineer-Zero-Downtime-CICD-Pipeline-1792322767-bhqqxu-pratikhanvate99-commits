variable "aws_region" {
  description = "Primary AWS Region (Mumbai)"
  type        = string
  default     = "ap-south-1"
}

variable "environment" {
  description = "Target deployment environment"
  type        = string
  default     = "production"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "novapay-banking-eks"
}

variable "db_instance_class" {
  description = "RDS Aurora Postgres instance class"
  type        = string
  default     = "db.r6g.2xlarge"
}
