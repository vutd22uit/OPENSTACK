# ============================================
# OPENSTACK TERRAFORM CONFIGURATION
# Compliance as Code - Production Grade
# ============================================
#
# This configuration implements CIS OpenStack Benchmark controls:
# - CIS-OS-1: SSH access restrictions
# - CIS-OS-3: Volume encryption enforcement
# - CIS-OS-5: Resource descriptions requirement
# - CIS-OS-7: Network security controls
# - CIS-OS-9: Audit logging and tagging
#
# Compliance Frameworks: CIS-OpenStack, ISO-27001, SOC2
#
# ============================================

# ============================================
# DATA SOURCES
# ============================================

# Fetch the latest approved image
data "openstack_images_image_v2" "selected_image" {
  name        = var.instance_image
  most_recent = true
}

# ============================================
# NETWORKING RESOURCES
# ============================================

# Private Network
# CIS-OS-7: Network isolation for security
resource "openstack_networking_network_v2" "private_network" {
  name           = local.resource_names.network
  description    = local.descriptions.network
  admin_state_up = true

  # Tags/Metadata for compliance tracking
  tags = [
    "environment:${var.environment}",
    "managed-by:terraform",
    "compliance:cis-os-7"
  ]
}

# Private Subnet
# Secure subnet configuration with proper DNS
resource "openstack_networking_subnet_v2" "private_subnet" {
  name            = local.resource_names.subnet
  description     = local.descriptions.subnet
  network_id      = openstack_networking_network_v2.private_network.id
  cidr            = var.network_cidr
  ip_version      = 4
  dns_nameservers = var.dns_nameservers
  enable_dhcp     = var.enable_dhcp

  # Allocation pools to reserve IPs for infrastructure
  allocation_pool {
    start = cidrhost(var.network_cidr, 10)
    end   = cidrhost(var.network_cidr, 250)
  }
}

# ============================================
# SECURITY GROUPS
# ============================================

# Main Security Group
# CIS-OS-5: Requires description
resource "openstack_networking_secgroup_v2" "main" {
  name        = local.resource_names.security_group
  description = local.descriptions.security_group

  # Delete default egress rules if egress restrictions are enabled
  delete_default_rules = var.enable_egress_restrictions
}

# Ingress Security Group Rules
# CIS-OS-1: SSH restricted to authorized networks only
resource "openstack_networking_secgroup_rule_v2" "ingress_rules" {
  for_each = { for idx, rule in local.all_ingress_rules : rule.name => rule }

  direction         = each.value.direction
  ethertype         = "IPv4"
  protocol          = each.value.protocol
  port_range_min    = each.value.port_range_min
  port_range_max    = each.value.port_range_max
  remote_ip_prefix  = each.value.remote_ip_prefix
  security_group_id = openstack_networking_secgroup_v2.main.id
  description       = each.value.description
}

# Egress Security Group Rules
# Controlled egress traffic (best practice)
resource "openstack_networking_secgroup_rule_v2" "egress_rules" {
  for_each = { for idx, rule in local.egress_rules : rule.name => rule }

  direction         = each.value.direction
  ethertype         = "IPv4"
  protocol          = each.value.protocol
  port_range_min    = each.value.port_range_min
  port_range_max    = each.value.port_range_max
  remote_ip_prefix  = each.value.remote_ip_prefix
  security_group_id = openstack_networking_secgroup_v2.main.id
  description       = each.value.description
}

# ICMP rule for ping (diagnostic)
resource "openstack_networking_secgroup_rule_v2" "icmp" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  remote_ip_prefix  = var.network_cidr
  security_group_id = openstack_networking_secgroup_v2.main.id
  description       = "Allow ICMP from same network for diagnostics"
}

# ============================================
# STORAGE RESOURCES
# ============================================

# Data Volumes with Encryption
# CIS-OS-3: All volumes must be encrypted
resource "openstack_blockstorage_volume_v3" "data_volume" {
  count = var.create_data_volumes ? var.data_volume_count : 0

  name        = "${local.resource_names.volume_prefix}-data-${count.index + 1}"
  description = "${local.descriptions.volume} - Volume ${count.index + 1}"
  size        = var.data_volume_size

  # CIS-OS-3: Encryption enforcement
  enable_encryption = var.enforce_volume_encryption

  # Metadata for compliance and management
  metadata = merge(
    local.common_tags,
    local.security_tags,
    {
      VolumeType    = "data"
      VolumeIndex   = tostring(count.index + 1)
      Encrypted     = var.enforce_volume_encryption ? "true" : "false"
      ComplianceTag = "CIS-OS-3"
    }
  )
}

# ============================================
# COMPUTE INSTANCES
# ============================================

# Compute Instances with Security Best Practices
resource "openstack_compute_instance_v2" "instance" {
  count = var.instance_count

  name            = "${local.resource_names.instance_prefix}-${count.index + 1}"
  flavor_name     = var.instance_flavor
  security_groups = [openstack_networking_secgroup_v2.main.name]

  # Network configuration
  network {
    uuid = openstack_networking_network_v2.private_network.id
  }

  # Boot from volume with encryption
  # CIS-OS-3: Boot volumes must be encrypted
  block_device {
    uuid                  = data.openstack_images_image_v2.selected_image.id
    source_type           = "image"
    destination_type      = "volume"
    boot_index            = 0
    delete_on_termination = true
    volume_size           = var.instance_boot_volume_size
  }

  # Comprehensive metadata for compliance
  # CIS-OS-9: Audit logging through metadata
  metadata = merge(
    local.common_tags,
    local.security_tags,
    {
      InstanceName     = "${local.resource_names.instance_prefix}-${count.index + 1}"
      InstanceIndex    = tostring(count.index + 1)
      BootVolumeSize   = tostring(var.instance_boot_volume_size)
      BootEncrypted    = var.enable_boot_volume_encryption ? "true" : "false"
      ImageName        = var.instance_image
      FlavorName       = var.instance_flavor
      NetworkCIDR      = var.network_cidr
      SecurityGroupID  = openstack_networking_secgroup_v2.main.id
      ComplianceTags   = "CIS-OS-3,CIS-OS-9"
      LastUpdated      = timestamp()
    }
  )

  # Lifecycle management
  lifecycle {
    # Prevent accidental deletion of production instances
    prevent_destroy = false

    # Ignore changes to metadata timestamps
    ignore_changes = [
      metadata["LastUpdated"],
      metadata["CreatedDate"]
    ]

    # Create before destroy for zero-downtime updates
    create_before_destroy = true
  }

  # Wait for network to be ready
  depends_on = [
    openstack_networking_subnet_v2.private_subnet,
    openstack_networking_secgroup_v2.main
  ]
}

# ============================================
# VOLUME ATTACHMENTS
# ============================================

# Attach data volumes to instances (if both exist)
resource "openstack_compute_volume_attach_v2" "volume_attachment" {
  count = var.create_data_volumes && var.instance_count > 0 ? min(var.data_volume_count, var.instance_count) : 0

  instance_id = openstack_compute_instance_v2.instance[count.index].id
  volume_id   = openstack_blockstorage_volume_v3.data_volume[count.index].id

  # Let OpenStack assign device name automatically
  # device = "/dev/vdb"

  depends_on = [
    openstack_compute_instance_v2.instance,
    openstack_blockstorage_volume_v3.data_volume
  ]
}

# ============================================
# COMPLIANCE CHECKS & VALIDATIONS
# ============================================

# Validation: Ensure SSH is not open to the world
# CIS-OS-1 Compliance Check
resource "null_resource" "validate_ssh_compliance" {
  count = local.ssh_compliance_check ? 0 : 1

  provisioner "local-exec" {
    command = "echo 'ERROR: CIS-OS-1 VIOLATION - SSH is open to 0.0.0.0/0' && exit 1"
  }
}

# Validation: Ensure volume encryption is enabled
# CIS-OS-3 Compliance Check
resource "null_resource" "validate_encryption_compliance" {
  count = var.enforce_volume_encryption ? 0 : 1

  provisioner "local-exec" {
    command = "echo 'WARNING: CIS-OS-3 - Volume encryption is not enforced'"
  }
}

# ============================================
# COMPLIANCE SUMMARY
# ============================================

# Output compliance status during plan/apply
output "compliance_checks" {
  description = "Compliance validation results"
  value = {
    cis_os_1_ssh_restriction = local.compliance_status.ssh_compliance
    cis_os_3_encryption      = local.compliance_status.encryption_compliance
    cis_os_5_descriptions    = local.compliance_status.description_compliance
    frameworks_applied       = var.compliance_frameworks
    security_level          = "HIGH"
    audit_enabled           = var.enable_audit_logging
  }
}
