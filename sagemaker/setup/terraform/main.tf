terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# VPC Configuration
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  
  name = "sagemaker-hyperpod-vpc"
  cidr = "10.0.0.0/16"
  
  azs             = ["${var.aws_region}a", "${var.aws_region}b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]
  
  enable_nat_gateway = true
  single_nat_gateway = true
  
  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

# EKS Cluster
module "eks" {
  source = "terraform-aws-modules/eks/aws"
  
  cluster_name    = "sagemaker-hyperpod-cluster"
  cluster_version = "1.28"
  
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets
  
  eks_managed_node_groups = {
    trn1 = {
      min_size     = 1
      max_size     = 4
      desired_size = 2
      
      instance_types = ["trn1.32xlarge"]
      
      iam_role_additional_policies = {
        AmazonFSxFullAccess = "arn:aws:iam::aws:policy/AmazonFSxFullAccess"
      }
    }
  }
  
  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

# FSx for Lustre
resource "aws_fsx_lustre_file_system" "training" {
  storage_capacity            = 1200
  subnet_ids                 = [module.vpc.private_subnets[0]]
  security_group_ids         = [aws_security_group.fsx.id]
  deployment_type            = "PERSISTENT_2"
  per_unit_storage_throughput = 250
  automatic_backup_retention_days = 0
  
  tags = {
    Name = "training-fsx"
  }
}

# Security Group for FSx
resource "aws_security_group" "fsx" {
  name        = "fsx-security-group"
  description = "Security group for FSx for Lustre"
  vpc_id      = module.vpc.vpc_id
  
  ingress {
    from_port   = 988
    to_port     = 988
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "fsx-security-group"
  }
}

# ECR Repository
resource "aws_ecr_repository" "training" {
  name = "peft-optimum-neuron"
  
  image_scanning_configuration {
    scan_on_push = true
  }
  
  tags = {
    Name = "training-repository"
  }
}

# IAM Role for SageMaker
resource "aws_iam_role" "sagemaker_execution" {
  name = "sagemaker-execution-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "sagemaker.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for SageMaker
resource "aws_iam_role_policy_attachment" "sagemaker_full_access" {
  role       = aws_iam_role.sagemaker_execution.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"
}

# Outputs
output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnets" {
  value = module.vpc.private_subnets
}

output "eks_cluster_id" {
  value = module.eks.cluster_id
}

output "fsx_id" {
  value = aws_fsx_lustre_file_system.training.id
}

output "ecr_repository_url" {
  value = aws_ecr_repository.training.repository_url
}

output "sagemaker_role_arn" {
  value = aws_iam_role.sagemaker_execution.arn
} 