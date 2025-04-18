# SageMaker HyperPod Scripts

This directory contains scripts for setting up and managing the SageMaker HyperPod environment for distributed training.

## ⚠️ Important Configuration Warning

This project supports two approaches for infrastructure management:

1. **Terraform Approach (Recommended)**
   - Uses Terraform for infrastructure management
   - Get environment variables from Terraform outputs:
     ```bash
     export AWS_REGION=$(terraform output -raw aws_region)
     export EKS_CLUSTER_NAME=$(terraform output -raw eks_cluster_id)
     export VPC_ID=$(terraform output -raw vpc_id)
     export PRIVATE_SUBNET_ID=$(terraform output -raw private_subnets | jq -r '.[0]')
     export SECURITY_GROUP_ID=$(terraform output -raw fsx_security_group_id)
     ```

2. **CloudFormation Approach (Alternative)**
   - Uses `create_config.sh` for infrastructure management
   - The script is downloaded from AWS samples repository
   - ⚠️ **Important: Credential Requirements**
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

   - ⚠️ **Required IAM permissions**:
     - CloudFormation:FullAccess
     - IAM:FullAccess
     - EKS:FullAccess
     - EC2:FullAccess
     - S3:FullAccess
     - FSx:FullAccess
     - ECR:FullAccess
   
   - ⚠️ **Before running the script**:
     1. Ensure AWS credentials are properly configured
     2. Verify you can run `aws sts get-caller-identity`
     3. Check that the CloudFormation stack exists
     4. Confirm you have the required IAM permissions

   - To run the configuration:
     ```bash
     ./config.sh  # This will download and run create_config.sh
     ```

   The script will:
   - Use AWS credentials from the standard AWS CLI credential chain
   - Retrieve resources from the specified CloudFormation stack
   - Export environment variables to `env_vars` file
   - Add source command to shell config files

3. **Important Notes**
   - ❌ Do not mix both approaches
   - Choose either Terraform OR CloudFormation
   - Each approach requires different setup steps
   - Environment variables will differ between approaches
   - The CloudFormation approach requires AWS credentials to be set up before running the scripts

## Script Execution Order

### If using Terraform:
```bash
# 1. Verify EKS cluster is up
./verify_eks.sh

# 2. Set up FSx for Lustre
./lustre_fs.sh

# 3. Build and push Docker image
./build_docker_image.sh

# 4. Generate job specifications
./generate-jobspec.sh --model llama3 --dataset alpaca

# 5. Start the training pipeline
./training.sh
```

### If using CloudFormation:
```bash
# 1. Run create_config.sh first
./create_config.sh

# 2. Follow the same order as above
./verify_eks.sh
./lustre_fs.sh
./build_docker_image.sh
./generate-jobspec.sh --model llama3 --dataset alpaca
./training.sh
```

## Script Dependencies and Flow

1. **verify_eks.sh**
   - Verifies EKS cluster accessibility
   - Configures kubectl context
   - Checks cluster services
   - Verifies Helm installations

2. **lustre_fs.sh**
   - Sets up OIDC provider for EKS
   - Installs FSx CSI driver
   - Creates IAM service account
   - Configures storage class and PVC
   - Tests FSx mount

3. **build_docker_image.sh**
   - Logs into AWS ECR
   - Pulls base DLC image
   - Builds training container
   - Pushes image to ECR

4. **generate-jobspec.sh**
   - Creates Kubernetes job specifications
   - Configures model and dataset parameters
   - Generates YAML files for:
     - Data tokenization
     - Model compilation
     - Training
     - Weight consolidation
     - LoRA merging

5. **training.sh**
   - Orchestrates the training process
   - Manages job execution
   - Provides monitoring and logging
   - Includes troubleshooting functions

6. **cleanup.sh**
   - Deletes training workloads
   - Removes FSx resources
   - Cleans up Helm charts
   - Deletes service accounts
   - Removes cluster resources
   - Cleans up environment variables

## Important Notes

- All scripts depend on Terraform-created infrastructure
- Environment variables should come from Terraform outputs
- The `training.sh` script includes monitoring and troubleshooting functions
- The `cleanup.sh` script should be run in reverse order of setup

## Troubleshooting

Common issues and solutions:

1. **Missing Environment Variables**
   - Ensure all required variables are set from Terraform outputs
   - Verify Terraform has completed successfully
   - Check Terraform outputs for correct values

2. **EKS Cluster Access**
   - If `verify_eks.sh` fails, check AWS credentials and region settings
   - Ensure the EKS cluster is in a running state
   - Verify kubectl context is properly configured

3. **FSx Mount Issues**
   - Verify IAM permissions for FSx access
   - Check network connectivity between EKS and FSx
   - Ensure security groups allow necessary traffic

4. **Training Job Failures**
   - Use the troubleshooting functions in `training.sh`
   - Check pod logs and events
   - Verify resource limits and requests

5. **Cleanup Issues**
   - Some resources may need manual cleanup if automated cleanup fails
   - Check CloudWatch logs for detailed error messages
   - Verify IAM permissions for resource deletion

## References

- [SageMaker HyperPod Documentation](https://docs.aws.amazon.com/sagemaker/latest/dg/hyperpod.html)
- [EKS Best Practices](https://docs.aws.amazon.com/eks/latest/userguide/best-practices.html)
- [FSx for Lustre Documentation](https://docs.aws.amazon.com/fsx/latest/LustreGuide/what-is.html) 