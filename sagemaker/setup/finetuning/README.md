# LoRA Fine-tuning with Optimum Neuron on SageMaker HyperPod EKS

This project implements efficient fine-tuning of large language models using LoRA (Low-Rank Adaptation) on Amazon SageMaker HyperPod with EKS orchestration. We specifically target the Llama 3.2 7B model using Optimum Neuron for optimized training on AWS Trainium instances.

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

1. **Setup Environment**
   ```bash
   # Export AWS credentials
   export AWS_ACCESS_KEY_ID="your_access_key"
   export AWS_SECRET_ACCESS_KEY="your_secret_key"
   export AWS_DEFAULT_REGION="ap-southeast-2"
   ```

2. **Initialize Training**
   ```bash
   # Generate job specifications
   ./generate-jobspec.sh --model llama3 --dataset alpaca

   # Start training pipeline
   ./training.sh
   ```

3. **Monitor Progress**
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

## Requirements

- AWS account with appropriate permissions
- SageMaker HyperPod access
- HuggingFace access token
- Python 3.11
- Required Python packages (see requirements.txt)

## References

- [SageMaker HyperPod Documentation](https://docs.aws.amazon.com/sagemaker/latest/dg/hyperpod.html)
- [Optimum Neuron Documentation](https://huggingface.co/docs/optimum-neuron/index)
- [LoRA Paper](https://arxiv.org/abs/2106.09685)
- [Llama 3.2 Documentation](https://huggingface.co/meta-llama/Meta-Llama-3.2-7B) 