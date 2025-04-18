# SageMaker HyperPod Setup with Terraform

This repository contains Terraform configurations and scripts to set up a SageMaker HyperPod environment for distributed training.

## Prerequisites

1. Install Terraform (v1.0.0 or later)
2. Install AWS CLI and configure credentials
3. Install kubectl
4. Install eksctl
5. Install Docker

## Setup Process

### 1. Initialize Terraform

```bash
terraform init
```

### 2. Review and Apply Terraform Configuration

```bash
terraform plan
terraform apply
```

This will create:
- VPC with public and private subnets
- EKS cluster with trn1.32xlarge nodes
- FSx for Lustre file system
- ECR repository
- IAM roles and policies

### 3. Configure kubectl

After Terraform completes, configure kubectl to access the EKS cluster:

```bash
aws eks --region $(terraform output -raw aws_region) update-kubeconfig --name $(terraform output -raw eks_cluster_id)
```

### 4. Run FSx Setup Script

Run the FSx setup script to configure the CSI driver and storage:

```bash
export EKS_CLUSTER_NAME=$(terraform output -raw eks_cluster_id)
export AWS_REGION=$(terraform output -raw aws_region)
export PRIVATE_SUBNET_ID=$(terraform output -raw private_subnets | jq -r '.[0]')
export SECURITY_GROUP_ID=$(terraform output -raw fsx_security_group_id)

./lustre_fs.sh
```

### 5. Build and Push Docker Image

Run the Docker image build script:

```bash
./build_docker_image.sh
```

## Architecture

The setup creates:
- A VPC with public and private subnets across two AZs
- An EKS cluster with trn1.32xlarge nodes
- FSx for Lustre for high-performance storage
- ECR repository for container images
- IAM roles and policies for SageMaker and FSx access

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

## Notes

- The FSx file system is configured with 1200 GiB storage and 250 MB/s/TiB throughput
- The EKS cluster is configured with trn1.32xlarge instances for training
- All resources are tagged with environment=dev
- The setup uses the us-east-1 region by default 