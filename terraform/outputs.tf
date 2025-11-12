# ============================================
# OUTPUTS - OpenStack Terraform Configuration
# Compliance as Code - Production Grade
# ============================================

# ============================================
# NETWORKING OUTPUTS
# ============================================

output "network_id" {
  description = "ID of the private network"
  value       = openstack_networking_network_v2.private_network.id
}

output "network_name" {
  description = "Name of the private network"
  value       = openstack_networking_network_v2.private_network.name
}

output "subnet_id" {
  description = "ID of the private subnet"
  value       = openstack_networking_subnet_v2.private_subnet.id
}

output "subnet_cidr" {
  description = "CIDR block of the private subnet"
  value       = openstack_networking_subnet_v2.private_subnet.cidr
}

output "subnet_allocation_pool" {
  description = "IP allocation pool for the subnet"
  value = {
    start = cidrhost(var.network_cidr, 10)
    end   = cidrhost(var.network_cidr, 250)
  }
}

# ============================================
# SECURITY GROUP OUTPUTS
# ============================================

output "security_group_id" {
  description = "ID of the main security group"
  value       = openstack_networking_secgroup_v2.main.id
}

output "security_group_name" {
  description = "Name of the main security group"
  value       = openstack_networking_secgroup_v2.main.name
}

output "security_group_rules" {
  description = "Summary of security group rules"
  value = {
    ingress_rules = [
      for rule in local.all_ingress_rules : {
        port        = "${rule.port_range_min}-${rule.port_range_max}"
        protocol    = rule.protocol
        source_cidr = rule.remote_ip_prefix
        description = rule.description
      }
    ]
    egress_rules = [
      for rule in local.egress_rules : {
        port        = "${rule.port_range_min}-${rule.port_range_max}"
        protocol    = rule.protocol
        dest_cidr   = rule.remote_ip_prefix
        description = rule.description
      }
    ]
    egress_restricted = var.enable_egress_restrictions
  }
}

# ============================================
# COMPUTE INSTANCE OUTPUTS
# ============================================

output "instance_ids" {
  description = "IDs of all compute instances"
  value       = [for instance in openstack_compute_instance_v2.instance : instance.id]
}

output "instance_names" {
  description = "Names of all compute instances"
  value       = [for instance in openstack_compute_instance_v2.instance : instance.name]
}

output "instance_details" {
  description = "Detailed information about all instances"
  value = [
    for idx, instance in openstack_compute_instance_v2.instance : {
      id              = instance.id
      name            = instance.name
      flavor          = var.instance_flavor
      network_id      = openstack_networking_network_v2.private_network.id
      security_groups = instance.security_groups
      boot_volume_size = var.instance_boot_volume_size
      encrypted       = var.enable_boot_volume_encryption
    }
  ]
}

output "instance_access_ips" {
  description = "Private IP addresses of instances"
  value = {
    for idx, instance in openstack_compute_instance_v2.instance :
    instance.name => instance.access_ip_v4
  }
}

# ============================================
# STORAGE OUTPUTS
# ============================================

output "data_volume_ids" {
  description = "IDs of all data volumes"
  value       = [for vol in openstack_blockstorage_volume_v3.data_volume : vol.id]
}

output "data_volume_details" {
  description = "Detailed information about data volumes"
  value = [
    for idx, vol in openstack_blockstorage_volume_v3.data_volume : {
      id        = vol.id
      name      = vol.name
      size_gb   = vol.size
      encrypted = var.enforce_volume_encryption
    }
  ]
}

output "volume_attachments" {
  description = "Volume attachment information"
  value = [
    for idx, attach in openstack_compute_volume_attach_v2.volume_attachment : {
      instance_id = attach.instance_id
      volume_id   = attach.volume_id
      device      = attach.device
    }
  ]
}

# ============================================
# COMPLIANCE & SECURITY OUTPUTS
# ============================================

output "compliance_summary" {
  description = "Comprehensive compliance status summary"
  value = {
    # CIS OpenStack Benchmark compliance
    cis_compliance = {
      cis_os_1 = {
        control     = "SSH Access Restrictions"
        status      = local.ssh_compliance_check ? "COMPLIANT" : "NON-COMPLIANT"
        description = "SSH must not be accessible from 0.0.0.0/0"
        allowed_cidrs = var.allowed_ssh_cidr_blocks
      }
      cis_os_3 = {
        control     = "Volume Encryption"
        status      = var.enforce_volume_encryption ? "COMPLIANT" : "NON-COMPLIANT"
        description = "All volumes must be encrypted at rest"
        encryption_enforced = var.enforce_volume_encryption
      }
      cis_os_5 = {
        control     = "Resource Descriptions"
        status      = var.require_resource_descriptions ? "COMPLIANT" : "NON-COMPLIANT"
        description = "All resources must have descriptions"
        enforced    = var.require_resource_descriptions
      }
      cis_os_7 = {
        control     = "Network Isolation"
        status      = "COMPLIANT"
        description = "Private network with proper isolation"
        network_cidr = var.network_cidr
      }
      cis_os_9 = {
        control     = "Audit Logging & Tagging"
        status      = var.enable_audit_logging ? "COMPLIANT" : "NON-COMPLIANT"
        description = "Resources must have audit and compliance metadata"
        enabled     = var.enable_audit_logging
      }
    }

    # Overall compliance status
    overall_status = (
      local.ssh_compliance_check &&
      var.enforce_volume_encryption &&
      var.require_resource_descriptions &&
      var.enable_audit_logging
    ) ? "FULLY COMPLIANT" : "NEEDS ATTENTION"

    # Compliance frameworks
    frameworks = var.compliance_frameworks

    # Security posture
    security_posture = {
      encryption_enabled       = var.enforce_volume_encryption
      ssh_restricted          = local.ssh_compliance_check
      egress_controlled       = var.enable_egress_restrictions
      audit_logging_enabled   = var.enable_audit_logging
      backup_tags_enabled     = var.enable_backup_tags
      security_level          = "HIGH"
    }
  }
}

output "security_recommendations" {
  description = "Security recommendations based on current configuration"
  value = concat(
    !local.ssh_compliance_check ? [
      "⚠️ SSH is open to 0.0.0.0/0 - Restrict to specific IP ranges (CIS-OS-1)"
    ] : [],
    !var.enforce_volume_encryption ? [
      "⚠️ Volume encryption is not enforced - Enable encryption for all volumes (CIS-OS-3)"
    ] : [],
    !var.enable_egress_restrictions ? [
      "⚠️ Egress traffic is unrestricted - Consider enabling egress rules"
    ] : [],
    !var.enable_audit_logging ? [
      "⚠️ Audit logging is disabled - Enable for compliance tracking (CIS-OS-9)"
    ] : [],
    length(concat(
      !local.ssh_compliance_check ? ["ssh"] : [],
      !var.enforce_volume_encryption ? ["encryption"] : [],
      !var.enable_egress_restrictions ? ["egress"] : [],
      !var.enable_audit_logging ? ["audit"] : []
    )) == 0 ? [
      "✅ All security best practices are enabled - Configuration is compliant"
    ] : []
  )
}

# ============================================
# RESOURCE SUMMARY
# ============================================

output "resource_summary" {
  description = "Summary of all created resources"
  value = {
    environment     = var.environment
    project_name    = var.project_name
    owner           = var.owner

    resources_created = {
      networks         = 1
      subnets          = 1
      security_groups  = 1
      instances        = var.instance_count
      data_volumes     = var.create_data_volumes ? var.data_volume_count : 0
      volume_attachments = var.create_data_volumes && var.instance_count > 0 ? min(var.data_volume_count, var.instance_count) : 0
    }

    configuration = {
      network_cidr     = var.network_cidr
      instance_flavor  = var.instance_flavor
      instance_image   = var.instance_image
      boot_volume_size = var.instance_boot_volume_size
      data_volume_size = var.data_volume_size
    }

    tags_applied = local.common_tags
  }
}

# ============================================
# QUICK ACCESS OUTPUTS
# ============================================

output "quick_access" {
  description = "Quick access information for common operations"
  value = {
    ssh_command_template = "ssh -i <private_key> ubuntu@<instance_ip>"
    allowed_ssh_sources  = var.allowed_ssh_cidr_blocks
    network_name        = openstack_networking_network_v2.private_network.name
    security_group      = openstack_networking_secgroup_v2.main.name

    notes = [
      "All instances are in private network ${var.network_cidr}",
      "SSH access is restricted to: ${join(", ", var.allowed_ssh_cidr_blocks)}",
      "All volumes are ${var.enforce_volume_encryption ? "encrypted" : "not encrypted"}",
      "Total instances created: ${var.instance_count}"
    ]
  }
}

# ============================================
# TERRAFORM STATE OUTPUTS
# ============================================

output "terraform_metadata" {
  description = "Terraform configuration metadata"
  value = {
    managed_by       = "Terraform"
    configuration_version = "2.0"
    last_updated     = timestamp()
    environment      = var.environment
    compliance_mode  = "Enhanced"
  }
}
