#!/bin/bash

# Default values
MODEL_CONFIG="llama3"
DATASET_CONFIG="alpaca"
NAMESPACE="kubeflow"
FSX_ID=""
ECR_REPO=""
ROLE_ARN=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --model)
            MODEL_CONFIG="$2"
            shift 2
            ;;
        --dataset)
            DATASET_CONFIG="$2"
            shift 2
            ;;
        --namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        --fsx-id)
            FSX_ID="$2"
            shift 2
            ;;
        --ecr-repo)
            ECR_REPO="$2"
            shift 2
            ;;
        --role-arn)
            ROLE_ARN="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Load configuration files
MODEL_CONFIG_FILE="../config/models/${MODEL_CONFIG}.yaml"
DATASET_CONFIG_FILE="../config/datasets/${DATASET_CONFIG}.yaml"

if [[ ! -f $MODEL_CONFIG_FILE ]]; then
    echo "Model configuration file not found: $MODEL_CONFIG_FILE"
    exit 1
fi

if [[ ! -f $DATASET_CONFIG_FILE ]]; then
    echo "Dataset configuration file not found: $DATASET_CONFIG_FILE"
    exit 1
fi

# Function to read YAML values using yq
function get_yaml_value() {
    local file=$1
    local path=$2
    yq eval "$path" "$file"
}

# Extract values from config files
MODEL_NAME=$(get_yaml_value "$MODEL_CONFIG_FILE" '.model.name')
HF_MODEL_ID=$(get_yaml_value "$MODEL_CONFIG_FILE" '.model.huggingface_id')
PEFT_METHOD=$(get_yaml_value "$MODEL_CONFIG_FILE" '.model.peft_method')
BATCH_SIZE=$(get_yaml_value "$MODEL_CONFIG_FILE" '.training.batch_size')
INSTANCE_TYPE=$(get_yaml_value "$MODEL_CONFIG_FILE" '.hardware.instance_type')

DATASET_NAME=$(get_yaml_value "$DATASET_CONFIG_FILE" '.dataset.name')
DATASET_PATH=$(get_yaml_value "$DATASET_CONFIG_FILE" '.dataset.source.path')
MAX_LENGTH=$(get_yaml_value "$DATASET_CONFIG_FILE" '.dataset.preprocessing.max_length')

# Generate tokenization job spec
cat > tokenize_data.yaml << EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: peft-tokenize-data
  namespace: ${NAMESPACE}
spec:
  template:
    spec:
      containers:
      - name: tokenizer
        image: ${ECR_REPO}:latest
        command: ["python", "tokenize_dataset.py"]
        env:
        - name: DATASET_NAME
          value: "${DATASET_NAME}"
        - name: DATASET_PATH
          value: "${DATASET_PATH}"
        - name: MODEL_NAME
          value: "${HF_MODEL_ID}"
        - name: MAX_LENGTH
          value: "${MAX_LENGTH}"
        volumeMounts:
        - name: fsx
          mountPath: /fsx
      volumes:
      - name: fsx
        persistentVolumeClaim:
          claimName: fsx-claim
      restartPolicy: Never
EOF

# Generate training job spec
cat > launch_peft_train.yaml << EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: peft-train
  namespace: ${NAMESPACE}
spec:
  template:
    spec:
      containers:
      - name: trainer
        image: ${ECR_REPO}:latest
        command: ["python", "train.py"]
        env:
        - name: MODEL_NAME
          value: "${HF_MODEL_ID}"
        - name: PEFT_METHOD
          value: "${PEFT_METHOD}"
        - name: BATCH_SIZE
          value: "${BATCH_SIZE}"
        - name: HF_ACCESS_TOKEN
          valueFrom:
            secretKeyRef:
              name: hf-secret
              key: token
        resources:
          limits:
            nvidia.com/gpu: "8"
        volumeMounts:
        - name: fsx
          mountPath: /fsx
      volumes:
      - name: fsx
        persistentVolumeClaim:
          claimName: fsx-claim
      nodeSelector:
        node.kubernetes.io/instance-type: ${INSTANCE_TYPE}
      restartPolicy: Never
EOF

# Generate model compilation spec
cat > compile_peft.yaml << EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: peft-compile
  namespace: ${NAMESPACE}
spec:
  template:
    spec:
      containers:
      - name: compiler
        image: ${ECR_REPO}:latest
        command: ["python", "compile_model.py"]
        env:
        - name: MODEL_NAME
          value: "${HF_MODEL_ID}"
        volumeMounts:
        - name: fsx
          mountPath: /fsx
      volumes:
      - name: fsx
        persistentVolumeClaim:
          claimName: fsx-claim
      restartPolicy: Never
EOF

# Generate weight consolidation spec
cat > consolidation.yaml << EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: peft-consolidate
  namespace: ${NAMESPACE}
spec:
  template:
    spec:
      containers:
      - name: consolidator
        image: ${ECR_REPO}:latest
        command: ["python", "consolidate_weights.py"]
        env:
        - name: MODEL_NAME
          value: "${HF_MODEL_ID}"
        - name: PEFT_METHOD
          value: "${PEFT_METHOD}"
        volumeMounts:
        - name: fsx
          mountPath: /fsx
      volumes:
      - name: fsx
        persistentVolumeClaim:
          claimName: fsx-claim
      restartPolicy: Never
EOF

# Generate LoRA merge spec
cat > merge_lora.yaml << EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: peft-merge-lora
  namespace: ${NAMESPACE}
spec:
  template:
    spec:
      containers:
      - name: merger
        image: ${ECR_REPO}:latest
        command: ["python", "merge_lora.py"]
        env:
        - name: MODEL_NAME
          value: "${HF_MODEL_ID}"
        volumeMounts:
        - name: fsx
          mountPath: /fsx
      volumes:
      - name: fsx
        persistentVolumeClaim:
          claimName: fsx-claim
      restartPolicy: Never
EOF

echo "Generated all job specifications successfully!"
echo "You can now run: kubectl apply -f <job-spec>.yaml" 