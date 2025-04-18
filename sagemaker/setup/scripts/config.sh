mkdir hyperpod

cd hyperpod

curl -O https://raw.githubusercontent.com/aws-samples/awsome-distributed-training/refs/heads/main/1.architectures/7.sagemaker-hyperpod-eks/create_config.sh 

chmod +x create_config.sh

export STACK_ID=hyperpod-eks-full-stack

./create_config.sh

source env_vars

cat env_vars