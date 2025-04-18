variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "aws_access_key_id" {
  description = "AWS access key ID"
  type        = string
  default     = ""
}

variable "aws_secret_access_key" {
  description = "AWS secret access key"
  type        = string
  default     = ""
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