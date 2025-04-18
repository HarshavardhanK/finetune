#!/bin/bash

# Get the current user's ARN
USER_ARN=$(aws sts get-caller-identity --query 'Arn' --output text)
USER_NAME=$(echo $USER_ARN | cut -d'/' -f2)

# Create the policy
POLICY_NAME="SageMakerHyperPodFullAccess"
POLICY_ARN=$(aws iam create-policy \
    --policy-name $POLICY_NAME \
    --policy-document file://iam_policy.json \
    --query 'Policy.Arn' \
    --output text)

# Attach the policy to the user
aws iam attach-user-policy \
    --user-name $USER_NAME \
    --policy-arn $POLICY_ARN

echo "Policy $POLICY_NAME has been created and attached to user $USER_NAME"
echo "Policy ARN: $POLICY_ARN" 