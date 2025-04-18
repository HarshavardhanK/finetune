#!/bin/bash

#Set environment variables
export NAMESPACE="kubeflow"
export EKS_CLUSTER_NAME="your-cluster-name"  #Replace with your actual cluster name
export AWS_REGION="ap-southeast-2"  #Replace with your actual region
export SUBNET_ID="your-subnet-id"  #Replace with your actual subnet ID

#Function to check if a command was successful
check_status() {
    if [ $? -eq 0 ]; then
        echo "Success: $1"
    else
        echo "Error: $1"
        exit 1
    fi
}

#Step 1: List all resources to identify workloads
echo "Step 1: Listing all resources in the cluster..."
kubectl get all -A
check_status "Listing resources"

#Step 2: Delete all training workloads
echo "Step 2: Deleting training workloads..."
echo "Deleting compile workload..."
kubectl delete -f ./compile_peft.yaml
check_status "Deleting compile workload"

echo "Deleting consolidation workload..."
kubectl delete -f ./consolidation.yaml
check_status "Deleting consolidation workload"

echo "Deleting training workload..."
kubectl delete -f ./launch_peft_train.yaml
check_status "Deleting training workload"

echo "Deleting LoRA merge workload..."
kubectl delete -f ./merge_lora.yaml
check_status "Deleting LoRA merge workload"

echo "Deleting tokenization workload..."
kubectl delete -f ./tokenize_data.yaml
check_status "Deleting tokenization workload"

#Step 3: Delete FSx related resources
echo "Step 3: Deleting FSx related resources..."
echo "Deleting FSx pod..."
kubectl delete -f ./pod.yaml
check_status "Deleting FSx pod"

echo "Deleting PVC..."
kubectl delete -f ./pvc.yaml
check_status "Deleting PVC"

echo "Deleting StorageClass..."
kubectl delete -f ./storageclass.yaml
check_status "Deleting StorageClass"

#Step 4: Delete Helm chart dependencies
echo "Step 4: Deleting Helm chart dependencies..."
helm delete hyperpod-dependencies -n kube-system
check_status "Deleting Helm chart"

#Step 5: Delete FSx CSI driver service account
echo "Step 5: Deleting FSx CSI driver service account..."
eksctl delete iamserviceaccount \
  --name fsx-csi-controller-sa \
  --namespace kube-system \
  --cluster $EKS_CLUSTER_NAME \
  --region $AWS_REGION
check_status "Deleting service account"

#Step 6: Delete HyperPod cluster
echo "Step 6: Deleting HyperPod cluster..."
aws sagemaker delete-cluster --cluster-name ml-cluster --region $AWS_REGION
check_status "Deleting HyperPod cluster"

#Step 7: Check and wait for EFA network interfaces to be removed
echo "Step 7: Checking EFA network interfaces..."
while true; do
    EFA_INTERFACES=$(aws ec2 describe-network-interfaces \
        --filters Name=subnet-id,Values=$SUBNET_ID Name=interface-type,Values=efa \
        --query "NetworkInterfaces[].NetworkInterfaceId" \
        --region $AWS_REGION)
    
    if [ "$EFA_INTERFACES" == "[]" ]; then
        echo "✅ All EFA network interfaces have been removed"
        break
    else
        echo "⏳ Waiting for EFA network interfaces to be removed..."
        sleep 30
    fi
done

#Step 8: Delete CloudFormation stack
echo "Step 8: Deleting CloudFormation stack..."
aws cloudformation delete-stack --stack-name hyperpod-eks-full-stack --region $AWS_REGION
check_status "Deleting CloudFormation stack"

#Step 9: Unset environment variables
echo "Step 9: Cleaning up environment variables..."
unset EKS_CLUSTER_NAME \
    EKS_CLUSTER_ARN \
    BUCKET_NAME \
    EXECUTION_ROLE \
    VPC_ID \
    SUBNET_ID \
    SECURITY_GROUP
check_status "Unsetting environment variables"

echo "Cleanup completed successfully!" 