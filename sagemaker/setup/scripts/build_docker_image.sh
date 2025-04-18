#!/bin/bash

#Set AWS region and DLC account ID
region=us-east-1
dlc_account_id=763104351884

#Login to AWS ECR for DLC images
aws ecr get-login-password --region $region | docker login --username AWS --password-stdin $dlc_account_id.dkr.ecr.$region.amazonaws.com

# Pull the base DLC image
docker pull ${dlc_account_id}.dkr.ecr.${region}.amazonaws.com/huggingface-pytorch-training-neuronx:2.1.2-transformers4.43.2-neuronx-py310-sdk2.20.0-ubuntu20.04-v1.0

#On your x86-64 based development environment:

#Navigate to your home directory or your preferred project directory, clone the repo

cd ~
git clone https://github.com/Captainia/awsome-distributed-training.git
cd awsome-distributed-training
git checkout optimum-neuron-eks
cd 3.test_cases/pytorch/optimum-neuron/llama3/kubernetes/fine-tuning

# Configure Docker build environment
export AWS_REGION=$(aws ec2 describe-availability-zones --output text --query 'AvailabilityZones[0].[RegionName]')
export ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
export REGISTRY=${ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/
export IMAGE=peft-optimum-neuron
export TAG=:latest


echo "Building Docker image..."
docker build $DOCKER_NETWORK -t ${REGISTRY}${IMAGE}${TAG} .

#Check if ECR repository exists and create if needed
export REGISTRY_COUNT=$(aws ecr describe-repositories | grep \"${IMAGE}\" | wc -l)
if [ "${REGISTRY_COUNT//[!0-9]/}" == "0" ]; then
    echo "Creating repository ${REGISTRY}${IMAGE} ..."
    aws ecr create-repository --repository-name ${IMAGE}
else
    echo "Repository ${REGISTRY}${IMAGE} already exists"
fi

#Login to private ECR registry
echo "Logging in to $REGISTRY ..."
aws ecr get-login-password | docker login --username AWS --password-stdin $REGISTRY

#Push image to ECR
echo "Pushing image to ECR..."
docker image push ${REGISTRY}${IMAGE}${TAG}