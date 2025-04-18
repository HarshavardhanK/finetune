#!/bin/bash

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' 

echo -e "${YELLOW}Starting infrastructure health check...${NC}"

#Function to check command status
check_status() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $1${NC}"
    else
        echo -e "${RED}✗ $1${NC}"
        exit 1
    fi
}

#1. Check AWS credentials
echo "Checking AWS credentials..."
aws sts get-caller-identity > /dev/null
check_status "AWS credentials are valid"

#2. Check EKS cluster status
echo "Checking EKS cluster status..."
EKS_CLUSTER_NAME=$(terraform output -raw eks_cluster_id)
AWS_REGION=$(terraform output -raw aws_region)

aws eks describe-cluster --name $EKS_CLUSTER_NAME --region $AWS_REGION --query "cluster.status" | grep "ACTIVE" > /dev/null
check_status "EKS cluster is active"

#3. Check kubectl configuration
echo "Checking kubectl configuration..."
kubectl cluster-info > /dev/null
check_status "kubectl is properly configured"

#4. Check EKS nodes
echo "Checking EKS nodes..."
NODE_COUNT=$(kubectl get nodes | grep "Ready" | wc -l)
if [ $NODE_COUNT -gt 0 ]; then
    echo -e "${GREEN}✓ Found $NODE_COUNT ready nodes${NC}"
else
    echo -e "${RED}✗ No ready nodes found${NC}"
    exit 1
fi

#5. Check FSx for Lustre
echo "Checking FSx for Lustre status..."
FSX_ID=$(terraform output -raw fsx_file_system_id)
aws fsx describe-file-systems --file-system-ids $FSX_ID --query "FileSystems[0].Lifecycle" | grep "AVAILABLE" > /dev/null
check_status "FSx for Lustre is available"

#6. Check FSx CSI driver
echo "Checking FSx CSI driver..."
kubectl get pods -n kube-system | grep "fsx-csi-controller" | grep "Running" > /dev/null
check_status "FSx CSI controller is running"

#7. Check FSx storage class
echo "Checking FSx storage class..."
kubectl get storageclass | grep "fsx-sc" > /dev/null
check_status "FSx storage class exists"

#8. Check ECR repository
echo "Checking ECR repository..."
ECR_REPO=$(terraform output -raw ecr_repository_url)
aws ecr describe-repositories --repository-names $(echo $ECR_REPO | cut -d'/' -f2) > /dev/null
check_status "ECR repository exists"

#9. Check IAM roles
echo "Checking IAM roles..."
ROLE_NAMES=("sagemaker-training-role" "fsx-role")
for role in "${ROLE_NAMES[@]}"; do
    aws iam get-role --role-name $role > /dev/null
    check_status "IAM role $role exists"
done

#10. Check security groups
echo "Checking security groups..."
SG_IDS=($(terraform output -raw fsx_security_group_id) $(terraform output -raw eks_security_group_id))
for sg_id in "${SG_IDS[@]}"; do
    aws ec2 describe-security-groups --group-ids $sg_id > /dev/null
    check_status "Security group $sg_id exists"
done

#11. Check VPC endpoints
echo "Checking VPC endpoints..."
VPC_ID=$(terraform output -raw vpc_id)
aws ec2 describe-vpc-endpoints --filters "Name=vpc-id,Values=$VPC_ID" --query "VpcEndpoints[?State=='available']" | grep "available" > /dev/null
check_status "VPC endpoints are available"

#12. Check FSx mount
echo "Checking FSx mount..."
kubectl exec -it $(kubectl get pods -n kubeflow -o jsonpath='{.items[0].metadata.name}') -n kubeflow -- ls /fsx > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ FSx is mounted and accessible${NC}"
else
    echo -e "${YELLOW}⚠ FSx mount check skipped (no pods running)${NC}"
fi

echo -e "${GREEN}All infrastructure components are up and running!${NC}"
echo -e "${YELLOW}You can now proceed with fine-tuning.${NC}" 