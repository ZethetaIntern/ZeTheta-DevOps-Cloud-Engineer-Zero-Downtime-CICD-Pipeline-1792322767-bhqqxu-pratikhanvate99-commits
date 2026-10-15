# Aurora PostgreSQL 16 Cluster with pgBouncer
resource "aws_rds_cluster" "aurora_postgres" {
  cluster_identifier      = "novapay-aurora-pg16-prod"
  engine                  = "aurora-postgresql"
  engine_version          = "16.1"
  database_name           = "novapay_banking"
  master_username         = "novapay_admin"
  manage_master_user_password = true

  backup_retention_period = 35
  preferred_backup_window = "18:00-19:00" # Low traffic window (UTC)
  storage_encrypted       = true
  kms_key_id              = aws_kms_key.rds_kms.arn

  deletion_protection     = true
  skip_final_snapshot     = false
  final_snapshot_identifier = "novapay-aurora-final-snapshot"

  serverlessv2_scaling_configuration {
    max_capacity = 64
    min_capacity = 4
  }
}

resource "aws_kms_key" "rds_kms" {
  description         = "KMS Key for Aurora DB Storage Encryption"
  enable_key_rotation = true
}

# Redis 7 In-Memory Cluster (3 Nodes)
resource "aws_elasticache_replication_group" "redis_cluster" {
  replication_group_id          = "novapay-redis7-cluster"
  description                   = "Distributed Redis session and caching cluster"
  node_type                     = "cache.r6g.xlarge"
  num_cache_clusters            = 3
  port                          = 6379
  automatic_failover_enabled    = true
  multi_az_enabled              = true
  at_rest_encryption_enabled    = true
  transit_encryption_enabled    = true
  auth_token                    = "DYNAMIC_MANAGED_VAULT_TOKEN"
  kms_key_id                    = aws_kms_key.rds_kms.arn
}
