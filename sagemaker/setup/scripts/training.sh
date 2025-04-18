#!/bin/bash

# Set environment variables
export HF_ACCESS_TOKEN="your_huggingface_token_here"  # Replace with your actual token
export NAMESPACE="kubeflow"

# Step 1: Generate job specification files
echo "Generating job specification files..."
bash generate-jobspec.sh

# Step 2: Tokenize Data
echo "Starting data tokenization..."
kubectl apply -f ./tokenize_data.yaml

# Monitor tokenization pod
echo "Monitoring tokenization pod..."
kubectl get pods -A
kubectl logs -f peft-tokenize-data -n $NAMESPACE

# Optional: Access tokenization pod for debugging
# kubectl exec -it pod/peft-tokenize-data -n $NAMESPACE -- /bin/bash

# Step 3: Compile the model
echo "Starting model compilation..."
kubectl apply -f ./compile_peft.yaml

# Monitor compilation
echo "Monitoring compilation progress..."
kubectl logs -f peft-llama3-do-compile-worker-0 -n $NAMESPACE

# Optional: Access compilation pod for debugging
# kubectl exec -it pod/peft-llama3-do-compile-worker-0 -n $NAMESPACE -- /bin/bash

# Step 4: Train the model
echo "Starting model training..."
kubectl apply -f ./launch_peft_train.yaml

# Monitor training
echo "Monitoring training progress..."
kubectl logs -f peft-llama3-do-train-worker-0 -n $NAMESPACE

# Optional: Access training pod for debugging
# kubectl exec -it pod/peft-llama3-do-train-worker-0 -n $NAMESPACE -- /bin/bash

# Step 5: Consolidate trained weights
echo "Starting weight consolidation..."
kubectl apply -f ./consolidation.yaml

# Step 6: Merge LoRA weights
echo "Starting LoRA weight merging..."
kubectl apply -f ./merge_lora.yaml

# Monitor final model output
echo "Checking final model output..."
kubectl exec -it pod/peft-merge-lora -n $NAMESPACE -- /bin/bash -c "ls /fsx/peft_ft/model_checkpoints/"

# Alternative: Check through fsx-app pod
echo "Alternative check through fsx-app pod..."
kubectl exec -it pod/fsx-app -n $NAMESPACE -- /bin/bash -c "ls /data/peft_ft/model_checkpoints/final_model_output/"

# Helper functions for troubleshooting
function check_pod_status() {
    kubectl get pods -n $NAMESPACE
}

function check_pod_logs() {
    local pod_name=$1
    kubectl logs -f $pod_name -n $NAMESPACE
}

function describe_pod() {
    local pod_name=$1
    kubectl describe pod $pod_name -n $NAMESPACE
}

function restart_training() {
    echo "Restarting training..."
    kubectl delete -f ./launch_peft_train.yaml
    kubectl apply -f ./launch_peft_train.yaml
}

# Usage examples for troubleshooting:
# check_pod_status
# check_pod_logs "peft-tokenize-data"
# describe_pod "peft-tokenize-data"
# restart_training