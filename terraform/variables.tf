# ============================================
# VARIABLES - OpenStack Terraform Configuration
# Compliance as Code - Enhanced Version
# ============================================

# ============================================
# GENERAL CONFIGURATION
# ============================================

variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string
  default     = "production"

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be dev, staging, or production."
  }
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "openstack-compliance"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "owner" {
  description = "Resource owner/team name"
  type        = string
  default     = "security-team"
}

variable "cost_center" {
  description = "Cost center for billing"
  type        = string
  default     = "IT-SEC-001"
}

# ============================================
# SECURITY GROUP CONFIGURATION
# ============================================

variable "allowed_ssh_cidr_blocks" {
  description = "CIDR blocks allowed for SSH access (CIS-OS-1 compliance)"
  type        = list(string)
  default     = ["192.168.1.0/24"]

  validation {
    condition = alltrue([
      for cidr in var.allowed_ssh_cidr_blocks :
      can(cidrhost(cidr, 0)) && cidr != "0.0.0.0/0"
    ])
    error_message = "SSH must not be open to 0.0.0.0/0 (CIS-OS-1 violation)."
  }
}

variable "allowed_http_cidr_blocks" {
  description = "CIDR blocks allowed for HTTP access"
  type        = list(string)
  default     = ["10.0.0.0/8"]
}

variable "allowed_https_cidr_blocks" {
  description = "CIDR blocks allowed for HTTPS access"
  type        = list(string)
  default     = ["10.0.0.0/8"]
}

variable "enable_egress_restrictions" {
  description = "Enable egress traffic restrictions (best practice)"
  type        = bool
  default     = true
}

# ============================================
# NETWORK CONFIGURATION
# ============================================

variable "network_cidr" {
  description = "CIDR block for private network"
  type        = string
  default     = "10.0.1.0/24"

  validation {
    condition     = can(cidrhost(var.network_cidr, 0))
    error_message = "Network CIDR must be a valid IPv4 CIDR block."
  }
}

variable "dns_nameservers" {
  description = "DNS nameservers for subnet"
  type        = list(string)
  default     = ["8.8.8.8", "8.8.4.4"]
}

variable "enable_dhcp" {
  description = "Enable DHCP on subnet"
  type        = bool
  default     = true
}

# ============================================
# COMPUTE CONFIGURATION
# ============================================

variable "instance_count" {
  description = "Number of compute instances to create"
  type        = number
  default     = 1

  validation {
    condition     = var.instance_count >= 0 && var.instance_count <= 10
    error_message = "Instance count must be between 0 and 10."
  }
}

variable "instance_flavor" {
  description = "Flavor for compute instances"
  type        = string
  default     = "m1.small"
}

variable "instance_image" {
  description = "Image name for compute instances"
  type        = string
  default     = "Ubuntu 22.04"
}

variable "instance_boot_volume_size" {
  description = "Boot volume size in GB"
  type        = number
  default     = 20

  validation {
    condition     = var.instance_boot_volume_size >= 10 && var.instance_boot_volume_size <= 500
    error_message = "Boot volume size must be between 10 and 500 GB."
  }
}

variable "enable_boot_volume_encryption" {
  description = "Enable encryption for boot volumes (CIS-OS-3 compliance)"
  type        = bool
  default     = true
}

# ============================================
# STORAGE CONFIGURATION
# ============================================

variable "create_data_volumes" {
  description = "Create additional data volumes"
  type        = bool
  default     = true
}

variable "data_volume_size" {
  description = "Size of data volumes in GB"
  type        = number
  default     = 10

  validation {
    condition     = var.data_volume_size >= 1 && var.data_volume_size <= 1000
    error_message = "Data volume size must be between 1 and 1000 GB."
  }
}

variable "data_volume_count" {
  description = "Number of data volumes to create"
  type        = number
  default     = 1

  validation {
    condition     = var.data_volume_count >= 0 && var.data_volume_count <= 5
    error_message = "Data volume count must be between 0 and 5."
  }
}

variable "enforce_volume_encryption" {
  description = "Enforce encryption on all volumes (CIS-OS-3 compliance)"
  type        = bool
  default     = true
}

# ============================================
# COMPLIANCE & SECURITY SETTINGS
# ============================================

variable "require_resource_descriptions" {
  description = "Require descriptions on all resources (CIS-OS-5 compliance)"
  type        = bool
  default     = true
}

variable "enable_audit_logging" {
  description = "Enable audit logging metadata tags"
  type        = bool
  default     = true
}

variable "enable_backup_tags" {
  description = "Add backup-related tags to resources"
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "Backup retention period in days"
  type        = number
  default     = 30

  validation {
    condition     = var.backup_retention_days >= 7 && var.backup_retention_days <= 365
    error_message = "Backup retention must be between 7 and 365 days."
  }
}

variable "compliance_frameworks" {
  description = "Compliance frameworks to adhere to"
  type        = list(string)
  default     = ["CIS-OpenStack", "ISO-27001", "SOC2"]
}

# ============================================
# TAGGING CONFIGURATION
# ============================================

variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "enable_cost_allocation_tags" {
  description = "Enable cost allocation tags"
  type        = bool
  default     = true
}
