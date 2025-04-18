# LoRA Finetuning using Self-Hosted Ray Distributed Training Setup

This repository contains configurations and scripts to set up a self-hosted Ray cluster environment for distributed training, specifically optimized for LoRA fine-tuning of large language models.

## Prerequisites

1. Multiple Linux servers with:
   - Ubuntu 20.04 or later
   - Python 3.11
   - NVIDIA GPUs (recommended)
   - High-speed network connectivity between nodes
2. Docker installed on all nodes
3. NFS or similar shared storage system
4. Required Python packages (see requirements.txt)

## Architecture Overview

### Core Components

1. **Ray Cluster**
   - Head node: Manages the cluster and coordinates tasks
   - Worker nodes: Execute distributed computations
   - Automatic scaling and fault tolerance
   - GPU support for accelerated training

2. **Shared Storage**
   - NFS server for shared model and data access
   - Mounted at `/shared` on all nodes
   - Enables efficient data access across cluster

3. **Training Infrastructure**
   - Docker containers for consistent environments
   - GPU passthrough for accelerated training
   - Network configuration for inter-node communication

## Setup Process

### 1. Configure Head Node

```bash
# Install Ray
pip install "ray[default]"

# Start Ray head node
ray start --head --port=6379 --dashboard-host=0.0.0.0
```

### 2. Configure Worker Nodes

```bash
# Install Ray
pip install "ray[default]"

# Connect to head node
ray start --address='<head-node-ip>:6379'
```

### 3. Setup Shared Storage

On the NFS server:
```bash
# Install NFS server
sudo apt-get install nfs-kernel-server

# Create shared directory
sudo mkdir -p /shared
sudo chown -R nobody:nogroup /shared
sudo chmod 777 /shared

# Configure exports
echo "/shared *(rw,sync,no_subtree_check)" | sudo tee -a /etc/exports
sudo exportfs -a
```

On worker nodes:
```bash
# Install NFS client
sudo apt-get install nfs-common

# Mount shared directory
sudo mkdir -p /shared
sudo mount <nfs-server-ip>:/shared /shared
```

### 4. Build and Deploy Docker Image

```bash
# Build training image
docker build -t ray-training:latest .

# Push to local registry or copy to all nodes
```

## Fine-tuning Implementation

### Key Features

1. **LoRA (Low-Rank Adaptation)**
   - Efficient parameter-efficient fine-tuning
   - Reduced memory footprint
   - Faster training convergence

2. **Ray Integration**
   - Optimized for distributed training
   - Automatic resource management
   - Fault tolerance and recovery

3. **Distributed Training**
   - Ray Data for efficient data loading
   - Automatic mixed precision training
   - Gradient accumulation support

### Training Pipeline

1. **Data Preparation**
   - Dataset tokenization and preprocessing
   - Instruction formatting
   - Distributed data loading with Ray Data

2. **Model Setup**
   - Base model loading
   - LoRA configuration
   - Quantization setup (4-bit)

3. **Training Process**
   - Distributed training with Ray
   - Checkpoint management
   - Progress monitoring

4. **Model Export**
   - LoRA weight merging
   - Final model compilation
   - Model artifact storage

## Usage

### Cluster Setup

1. **Start Ray Cluster**
   ```bash
   # On head node
   ray start --head --port=6379 --dashboard-host=0.0.0.0

   # On worker nodes
   ray start --address='<head-node-ip>:6379'
   ```

2. **Verify Cluster Status**
   ```bash
   # Check cluster status
   ray status

   # View dashboard
   # Open browser to http://<head-node-ip>:8265
   ```

3. **Initialize Training**
   ```bash
   # Generate job specifications
   ./generate-jobspec.sh --model llama3 --dataset alpaca

   # Start training pipeline
   ./training.sh
   ```

4. **Monitor Progress**
   ```bash
   # View training logs
   tail -f /shared/training.log

   # Check GPU utilization
   nvidia-smi
   ```

## Benefits

1. **Efficiency**
   - Reduced memory usage through LoRA
   - Optimized GPU utilization
   - Efficient data handling with shared storage

2. **Scalability**
   - Distributed training support
   - Easy node addition/removal
   - Long-running job stability

3. **Flexibility**
   - Configurable model and dataset parameters
   - Support for different PEFT methods
   - Easy integration with HuggingFace ecosystem

## Cleanup

To stop the Ray cluster:

```bash
# On all nodes
ray stop
```

## Notes

- Ensure all nodes have sufficient GPU memory for model training
- Network bandwidth between nodes should be at least 10Gbps
- Shared storage should have sufficient capacity for models and datasets
- Consider using Docker Swarm or similar for container orchestration

## References

- [Ray Documentation](https://docs.ray.io/en/latest/)
- [Ray Cluster Setup](https://docs.ray.io/en/latest/cluster/index.html)
- [LoRA Paper](https://arxiv.org/abs/2106.09685)
- [Llama 3.2 Documentation](https://huggingface.co/meta-llama/Meta-Llama-3.2-7B)
