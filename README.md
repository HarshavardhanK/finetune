# LoRA Finetuning using Distributed Infrastructure

This repository contains Terraform configurations and scripts to set up a SageMaker HyperPod environment for distributed training, specifically optimized for LoRA fine-tuning of large language models using Optimum Neuron.

## ⚠️ Important Configuration Warning

This project uses Terraform for infrastructure management. There is a potential conflict with the CloudFormation-based approach in the scripts directory:

1. **Configuration Conflict**
   - The `sagemaker/setup/scripts/config.sh` and `create_config.sh` use CloudFormation
   - This project uses Terraform for infrastructure management
   - Running both approaches will cause conflicts

2. **Do Not Mix Approaches**
   - ❌ Do not run `config.sh` or `create_config.sh` if using Terraform
   - ❌ Do not use CloudFormation stack creation if using Terraform
   - ✅ Use only one approach: either Terraform OR CloudFormation

3. **Alternative: Using create_config.sh**
   If you prefer to use CloudFormation instead of Terraform:
   
   ⚠️ **Important: Credential Requirements**
   The script relies on AWS CLI's credential chain, so you must have AWS credentials configured in one of these ways:

   ```bash
   # Method 1: Environment variables (Recommended)
   export AWS_ACCESS_KEY_ID="your_access_key"
   export AWS_SECRET_ACCESS_KEY="your_secret_key"
   export AWS_REGION="your_region"
   export STACK_ID="hyperpod-eks-full-stack"  # Default CloudFormation stack name
   
   # Method 2: AWS CLI configuration
   aws configure
   # Then enter your credentials when prompted
   
   # Method 3: AWS credentials file (~/.aws/credentials)
   [default]
   aws_access_key_id = your_access_key
   aws_secret_access_key = your_secret_key
   region = your_region
   ```

   The script will automatically use credentials in this order:
   1. Environment variables
   2. AWS CLI configuration
   3. AWS credentials file

   ⚠️ **Required IAM permissions**:
   - CloudFormation:FullAccess
   - IAM:FullAccess
   - EKS:FullAccess
   - EC2:FullAccess
   - S3:FullAccess
   - FSx:FullAccess
   - ECR:FullAccess

   ⚠️ **Before running the script**:
   1. Ensure AWS credentials are properly configured
   2. Verify you can run `aws sts get-caller-identity`
   3. Check that the CloudFormation stack exists
   4. Confirm you have the required IAM permissions

   To run the configuration:
   ```bash
   ./sagemaker/setup/scripts/config.sh  # This will download and run create_config.sh
   ```

   The script will:
   - Use AWS credentials from the standard AWS CLI credential chain
   - Retrieve resources from the specified CloudFormation stack
   - Export environment variables to `env_vars` file
   - Add source command to shell config files

4. **Why This Matters**
   - Mixing approaches can lead to:
     - Resource conflicts
     - Duplicate resource creation
     - Conflicting environment variables
     - Permission issues
     - Billing for duplicate resources

5. **Correct Setup Process**
   - Choose ONE approach:
     - Option 1: Use the Terraform-based setup described in this README
     - Option 2: Use the CloudFormation-based setup with `create_config.sh`
   - Do not mix both approaches
   - Follow the corresponding script execution order in `sagemaker/setup/scripts/README.md`

## Prerequisites

1. Install Terraform (v1.0.0 or later)
2. Install AWS CLI and configure credentials
3. Install kubectl
4. Install eksctl
5. Install Docker
6. Python 3.11
7. Required Python packages (see requirements.txt)

## Architecture Overview

### Core Components

1. **Amazon SageMaker HyperPod**
   - Provides built-in health checks and resiliency
   - Enables automatic node recovery and training job auto-resume
   - Supports long-running training jobs (months) without disruption
   - Uses trn1.32xlarge instances for optimal training throughput

2. **Amazon EKS Cluster**
   - Acts as the orchestration layer for HyperPod compute nodes
   - Manages ML workload distribution and scheduling
   - Provides Kubernetes API for job management

3. **Amazon FSx for Lustre**
   - Shared file system mounted at `/fsx`
   - Enables efficient data access across all HyperPod nodes
   - Supports high-performance parallel file access

4. **Training Infrastructure**
   - Private subnet for secure network access
   - Security groups configured for EFA network devices
   - Kubeflow Training Operator for job orchestration

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

## Fine-tuning Implementation

### Key Features

1. **LoRA (Low-Rank Adaptation)**
   - Efficient parameter-efficient fine-tuning
   - Reduced memory footprint
   - Faster training convergence

2. **Optimum Neuron Integration**
   - Optimized for AWS Trainium instances
   - Automatic model compilation
   - Hardware-specific optimizations

3. **Distributed Training**
   - FSDP (Fully Sharded Data Parallel) strategy
   - Gradient accumulation for larger effective batch sizes
   - Automatic mixed precision training

### Training Pipeline

1. **Data Preparation**
   - Dataset tokenization and preprocessing
   - Instruction formatting
   - Validation split creation

2. **Model Setup**
   - Base model loading (Llama 3.2 7B)
   - LoRA configuration
   - Quantization setup (4-bit)

3. **Training Process**
   - Distributed training orchestration
   - Checkpoint management
   - Progress monitoring

4. **Model Export**
   - LoRA weight merging
   - Final model compilation
   - Model artifact storage

## Usage

### Infrastructure Setup

1. **Export AWS credentials**
   ```bash
   export AWS_ACCESS_KEY_ID="your_access_key"
   export AWS_SECRET_ACCESS_KEY="your_secret_key"
   export AWS_DEFAULT_REGION="ap-southeast-2"
   ```

2. **Run Infrastructure Health Check**
   ```bash
   # Make the script executable
   chmod +x sagemaker/setup/health_check.sh
   
   # Run the health check
   ./sagemaker/setup/health_check.sh
   ```
   
   This script will verify:
   - AWS credentials and permissions
   - EKS cluster status and node availability
   - FSx for Lustre file system status
   - Required IAM roles and security groups
   - VPC endpoints and network connectivity
   - Storage class and CSI driver status
   - ECR repository access

3. **Initialize Training**
   ```bash
   # Generate job specifications
   ./sagemaker/setup/finetuning/generate-jobspec.sh --model llama3 --dataset alpaca

   # Start training pipeline
   ./sagemaker/setup/finetuning/training.sh
   ```

4. **Monitor Progress**
   ```bash
   # Check training status
   kubectl get pods -n kubeflow

   # View training logs
   kubectl logs -f peft-llama3-do-train-worker-0 -n kubeflow
   ```

## Benefits

1. **Efficiency**
   - Reduced memory usage through LoRA
   - Optimized training on Trainium instances
   - Efficient data handling with FSx

2. **Scalability**
   - Distributed training support
   - Automatic node recovery
   - Long-running job stability

3. **Flexibility**
   - Configurable model and dataset parameters
   - Support for different PEFT methods
   - Easy integration with HuggingFace ecosystem

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

## References

- [SageMaker HyperPod Documentation](https://docs.aws.amazon.com/sagemaker/latest/dg/hyperpod.html)
- [Optimum Neuron Documentation](https://huggingface.co/docs/optimum-neuron/index)
- [LoRA Paper](https://arxiv.org/abs/2106.09685)
- [Llama 3.2 Documentation](https://huggingface.co/meta-llama/Meta-Llama-3.2-7B) 