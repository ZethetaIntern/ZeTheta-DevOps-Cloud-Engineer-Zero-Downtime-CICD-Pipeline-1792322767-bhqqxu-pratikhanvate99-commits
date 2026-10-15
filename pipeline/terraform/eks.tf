# EKS Cluster Module across 3 Availability Zones
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.8"

  cluster_name    = var.cluster_name
  cluster_version = "1.29"

  cluster_endpoint_public_access  = false # No public endpoint (RBI Requirement)
  cluster_endpoint_private_access = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    banking_nodes = {
      min_size     = 6
      max_size     = 30
      desired_size = 9

      instance_types = ["m6i.2xlarge"]
      capacity_type  = "ON_DEMAND"

      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 100
            volume_type           = "gp3"
            encrypted             = true
            kms_key_id            = aws_kms_key.ebs_kms.arn
            delete_on_termination = true
          }
        }
      }

      labels = {
        Workload = "Tier1-Banking"
      }
    }
  }
}

resource "aws_kms_key" "ebs_kms" {
  description             = "NovaPay EBS KMS Customer Managed Key"
  deletion_window_in_days = 30
  enable_key_rotation     = true
}
