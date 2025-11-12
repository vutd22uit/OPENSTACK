# OpenStack Resources cho Compliance Testing
# File này chứa các resource để test compliance checks

# ============================================
# SECURITY GROUPS
# ============================================

# Security Group - COMPLIANT (có description)
resource "openstack_networking_secgroup_v2" "compliant_sg" {
  name        = "compliant-security-group"
  description = "Security group with proper configuration - CIS-OS-5 PASS"
}

# Security Group Rule - HTTP từ specific IP (COMPLIANT)
resource "openstack_networking_secgroup_rule_v2" "http_rule" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "10.0.0.0/8"  # Chỉ cho phép từ private network
  security_group_id = openstack_networking_secgroup_v2.compliant_sg.id
  description       = "Allow HTTP from internal network"
}

# Security Group Rule - SSH từ specific IP (COMPLIANT)
resource "openstack_networking_secgroup_rule_v2" "ssh_restricted" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "192.168.1.0/24"  # Chỉ từ admin network
  security_group_id = openstack_networking_secgroup_v2.compliant_sg.id
  description       = "SSH access from admin network only - CIS-OS-1 PASS"
}

# ============================================
# NON-COMPLIANT EXAMPLES (để test policies)
# ============================================

# Security Group - NON-COMPLIANT (không có description)
# Uncomment để test CIS-OS-5 violation
# resource "openstack_networking_secgroup_v2" "non_compliant_sg" {
#   name = "no-description-sg"
#   # Missing description - CIS-OS-5 FAIL
# }

# Security Group Rule - NON-COMPLIANT (SSH open to world)
# Uncomment để test CIS-OS-1 violation
# resource "openstack_networking_secgroup_rule_v2" "ssh_open_world" {
#   direction         = "ingress"
#   ethertype         = "IPv4"
#   protocol          = "tcp"
#   port_range_min    = 22
#   port_range_max    = 22
#   remote_ip_prefix  = "0.0.0.0/0"  # NGUY HIỂM - CIS-OS-1 FAIL
#   security_group_id = openstack_networking_secgroup_v2.compliant_sg.id
# }

# ============================================
# VOLUMES (Block Storage)
# ============================================

# Volume - COMPLIANT (encrypted)
resource "openstack_blockstorage_volume_v3" "encrypted_volume" {
  name        = "encrypted-volume"
  description = "Encrypted volume for sensitive data"
  size        = 10
  encrypted   = true  # CIS-OS-3 PASS
}

# Volume - NON-COMPLIANT (not encrypted)
# Uncomment để test CIS-OS-3 violation
# resource "openstack_blockstorage_volume_v3" "unencrypted_volume" {
#   name        = "unencrypted-volume"
#   size        = 10
#   encrypted   = false  # CIS-OS-3 FAIL
# }

# ============================================
# COMPUTE INSTANCES
# ============================================

# Data source để lấy image
data "openstack_images_image_v2" "ubuntu" {
  name        = "Ubuntu 22.04"
  most_recent = true
}

# Data source để lấy flavor
data "openstack_compute_flavor_v2" "small" {
  name = "m1.small"
}

# Instance - COMPLIANT (không có floating IP không cần thiết)
resource "openstack_compute_instance_v2" "compliant_instance" {
  name            = "compliant-instance"
  flavor_id       = data.openstack_compute_flavor_v2.small.id
  security_groups = [openstack_networking_secgroup_v2.compliant_sg.name]

  # Network configuration - REQUIRED
  network {
    uuid = openstack_networking_network_v2.private_network.id
  }

  # Block device với encryption
  block_device {
    uuid                  = data.openstack_images_image_v2.ubuntu.id
    source_type           = "image"
    destination_type      = "volume"
    boot_index            = 0
    delete_on_termination = true
    volume_size           = 20
  }

  metadata = {
    compliance  = "true"
    environment = "production"
    owner       = "security-team"
  }
}

# ============================================
# NETWORKING
# ============================================

# Network
resource "openstack_networking_network_v2" "private_network" {
  name           = "private-network"
  admin_state_up = true
}

# Subnet
resource "openstack_networking_subnet_v2" "private_subnet" {
  name       = "private-subnet"
  network_id = openstack_networking_network_v2.private_network.id
  cidr       = "10.0.1.0/24"
  ip_version = 4
  dns_nameservers = ["8.8.8.8", "8.8.4.4"]
}

# ============================================
# OUTPUTS
# ============================================

output "compliant_sg_id" {
  description = "ID của security group compliant"
  value       = openstack_networking_secgroup_v2.compliant_sg.id
}

output "encrypted_volume_id" {
  description = "ID của volume được mã hóa"
  value       = openstack_blockstorage_volume_v3.encrypted_volume.id
}

output "compliant_instance_id" {
  description = "ID của instance compliant"
  value       = openstack_compute_instance_v2.compliant_instance.id
}
