variable "name" {
  description = "Base name for site resources."
  type        = string
}

variable "domain_name" {
  description = "Domain name for ACM certificate."
  type        = string
}

variable "image" {
  description = "Container image for the ECS task."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for target group attachment."
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for ALB and ECS networking."
  type        = list(string)
}

variable "container_port" {
  description = "Container and target group port."
  type        = number
  default     = 80
}

variable "cpu" {
  description = "Task CPU units."
  type        = number
  default     = 256
}

variable "memory" {
  description = "Task memory in MiB."
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Desired ECS service task count."
  type        = number
  default     = 1
}

variable "assign_public_ip" {
  description = "Whether ECS tasks receive public IPs."
  type        = bool
  default     = true
}

variable "environment" {
  description = "Environment variables to inject into the container."
  type        = map(string)
  default     = {}
}
