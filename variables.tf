# AWS region where the temporary environment will run.
variable "aws_region" {
  description = "AWS region for the temporary testing environment."
  type        = string
  default     = "us-east-1"
}

# Name used to identify the project resources.
variable "project_name" {
  description = "Short project name used in resource names and tags."
  type        = string
  default     = "vendor-pentest"
}

# Person or team responsible for the environment.
variable "owner" {
  description = "Team or person responsible for this environment."
  type        = string
}

# Human-readable reason for creating the environment.
variable "purpose" {
  description = "Purpose tag for the environment."
  type        = string
  default     = "temporary penetration testing"
}

# Date when the temporary environment should expire.
variable "expiration_date" {
  description = "Date after which the environment must be removed, in YYYY-MM-DD format."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", var.expiration_date))
    error_message = "expiration_date must use YYYY-MM-DD format."
  }
}

# Approved VPC for the testing instance.
variable "vpc_id" {
  description = "Approved VPC ID."
  type        = string
  default     = "vpc-0c243d91f28423c5a" ## my existing VPC ID, replace with your own

}

# Approved subnet for the testing instance.
variable "subnet_id" {
  description = "Approved private or public subnet ID for the testing instance."
  type        = string
  default     = "subnet-05bfa8c76d79adb5d" ## my existing subnet ID, replace with your own
}

# EC2 size allocated to the testing workload.
variable "instance_type" {
  description = "EC2 instance type sized for the engagement."
  type        = string
  default     = "t3.medium"
}

# Size of the encrypted tools and test-output disk.
variable "tool_volume_size_gib" {
  description = "Encrypted gp3 EBS volume size for tools and test output."
  type        = number
  default     = 100

  validation {
    condition     = var.tool_volume_size_gib >= 20
    error_message = "tool_volume_size_gib must be at least 20 GiB."
  }
}

# Vendor source networks allowed to connect over SSH.
variable "allowed_ssh_cidr_blocks" {
  description = "Approved vendor source CIDRs for SSH. Leave empty when using SSM only."
  type        = list(string)
  default     = []
}

# Enables restricted SSH access when the approved CIDRs are supplied.
variable "enable_ssh" {
  description = "Whether to permit SSH from allowed_ssh_cidr_blocks. SSM remains available."
  type        = bool
  default     = false
}

# Individual operating-system accounts and their optional public keys.
variable "testers" {
  description = "Tester OS accounts. Each tester should have an approved SSH public key when SSH is enabled."
  type = list(object({
    username       = string
    ssh_public_key = optional(string, "")
  }))

  validation {
    condition     = length(var.testers) > 0
    error_message = "At least one tester account must be configured."
  }
}

# Number of days to retain host logs in CloudWatch.
variable "log_retention_days" {
  description = "CloudWatch log retention period."
  type        = number
  default     = 30
}

# Optional approved AMI; an Amazon Linux AMI is selected when empty.
variable "ami_id" {
  description = "Optional approved Linux AMI ID. If empty, the latest Amazon Linux 2023 AMI is selected."
  type        = string
  default     = ""
}

# Additional organization-specific resource tags.
variable "extra_tags" {
  description = "Additional tags required by the organization."
  type        = map(string)
  default     = {}
}