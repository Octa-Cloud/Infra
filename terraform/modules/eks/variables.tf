variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.28"
}

variable "subnet_ids" {
  description = "List of subnet IDs for the EKS cluster"
  type        = list(string)
}

variable "node_desired_size" {
  description = "Desired number of nodes in the node group"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum number of nodes in the node group"
  type        = number
  default     = 4
}

variable "node_min_size" {
  description = "Minimum number of nodes in the node group"
  type        = number
  default     = 1
}

variable "node_instance_types" {
  description = "Instance types for the node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
