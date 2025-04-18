variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "sagemaker-hyperpod-cluster"
}

variable "fsx_storage_capacity" {
  description = "Storage capacity for FSx for Lustre in GiB"
  type        = number
  default     = 1200
}

variable "fsx_throughput" {
  description = "Per unit storage throughput for FSx for Lustre"
  type        = number
  default     = 250
} 