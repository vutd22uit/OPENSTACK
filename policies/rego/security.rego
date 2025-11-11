package openstack

# ============================================
# CIS OpenStack Benchmark Policies
# 5 Controls Implementation
# ============================================

# ============================================
# CIS-OS-1: SSH không được mở 0.0.0.0/0
# Severity: CRITICAL
# ============================================

deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "openstack_networking_secgroup_rule_v2"

    # Check nếu là SSH port (22)
    resource.change.after.protocol == "tcp"
    resource.change.after.port_range_min == 22

    # Check nếu mở cho toàn bộ internet
    resource.change.after.remote_ip_prefix == "0.0.0.0/0"

    msg := sprintf("❌ BLOCKED [CIS-OS-1]: SSH port 22 open to internet (0.0.0.0/0) in '%s'. CRITICAL SECURITY RISK!", [resource.address])
}

# ============================================
# CIS-OS-2: Default security group không có rule
# Severity: HIGH
# ============================================

# Check xem có security group rule nào được tạo cho default SG không
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "openstack_networking_secgroup_rule_v2"

    # Lấy security group name từ reference hoặc name
    sg_name := resource.change.after.security_group_id
    contains(lower(sg_name), "default")

    msg := sprintf("❌ BLOCKED [CIS-OS-2]: Rule added to default security group in '%s'. Default SG must remain empty!", [resource.address])
}

# Alternate check cho default security group
warn[msg] {
    resource := input.resource_changes[_]
    resource.type == "openstack_networking_secgroup_v2"

    resource.change.after.name == "default"

    msg := sprintf("⚠️  WARNING [CIS-OS-2]: Modifying default security group '%s'. This is not recommended!", [resource.address])
}

# ============================================
# CIS-OS-3: Volume phải được encrypt
# Severity: HIGH
# ============================================

deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "openstack_blockstorage_volume_v3"

    # Check nếu volume không được encrypt
    not resource.change.after.encrypted

    msg := sprintf("❌ BLOCKED [CIS-OS-3]: Volume '%s' is not encrypted. All volumes must use encryption!", [resource.address])
}

# Warn nếu volume được encrypt nhưng không có description
warn[msg] {
    resource := input.resource_changes[_]
    resource.type == "openstack_blockstorage_volume_v3"

    resource.change.after.encrypted == true

    # Check nếu không có description
    not resource.change.after.description

    msg := sprintf("⚠️  WARNING [CIS-OS-3]: Volume '%s' lacks description. Add description for better tracking!", [resource.address])
}

# ============================================
# CIS-OS-4: Instance không có floating IP không cần thiết
# Severity: MEDIUM
# ============================================

# Warn nếu instance có floating IP được attach trực tiếp
warn[msg] {
    resource := input.resource_changes[_]
    resource.type == "openstack_compute_floatingip_associate_v2"

    msg := sprintf("⚠️  WARNING [CIS-OS-4]: Floating IP attached to instance in '%s'. Verify if public access is necessary!", [resource.address])
}

# Check nếu floating IP được tạo
warn[msg] {
    resource := input.resource_changes[_]
    resource.type == "openstack_networking_floatingip_v2"

    msg := sprintf("⚠️  WARNING [CIS-OS-4]: Floating IP created in '%s'. Ensure it's required and properly secured!", [resource.address])
}

# ============================================
# CIS-OS-5: Security group phải có description
# Severity: LOW
# ============================================

deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "openstack_networking_secgroup_v2"

    # Check nếu không có description hoặc description empty
    not resource.change.after.description

    # Skip default security group
    resource.change.after.name != "default"

    msg := sprintf("❌ BLOCKED [CIS-OS-5]: Security group '%s' missing description. All security groups must have descriptions!", [resource.address])
}

# Check nếu description quá ngắn (< 10 characters)
warn[msg] {
    resource := input.resource_changes[_]
    resource.type == "openstack_networking_secgroup_v2"

    desc := resource.change.after.description
    count(desc) > 0
    count(desc) < 10

    msg := sprintf("⚠️  WARNING [CIS-OS-5]: Security group '%s' has very short description (%d chars). Use descriptive text!", [resource.address, count(desc)])
}

# ============================================
# ADDITIONAL SECURITY CHECKS
# ============================================

# Warn nếu security group rule cho phép tất cả protocols
warn[msg] {
    resource := input.resource_changes[_]
    resource.type == "openstack_networking_secgroup_rule_v2"

    # Protocol -1 hoặc "all" cho phép tất cả
    resource.change.after.protocol == "-1"

    msg := sprintf("⚠️  WARNING: Security group rule '%s' allows ALL protocols. Consider restricting to specific protocols!", [resource.address])
}

# Warn nếu có port range quá rộng
warn[msg] {
    resource := input.resource_changes[_]
    resource.type == "openstack_networking_secgroup_rule_v2"

    min_port := resource.change.after.port_range_min
    max_port := resource.change.after.port_range_max

    # Check nếu port range > 100
    port_range := max_port - min_port
    port_range > 100

    msg := sprintf("⚠️  WARNING: Security group rule '%s' has wide port range (%d-%d). Consider restricting to necessary ports only!", [resource.address, min_port, max_port])
}

# Check instance metadata cho compliance tracking
warn[msg] {
    resource := input.resource_changes[_]
    resource.type == "openstack_compute_instance_v2"

    # Check nếu không có metadata
    not resource.change.after.metadata

    msg := sprintf("⚠️  WARNING: Instance '%s' has no metadata. Add owner/compliance tags for better tracking!", [resource.address])
}

# ============================================
# HELPER FUNCTIONS
# ============================================

# Check nếu IP là private range
is_private_ip(ip) {
    startswith(ip, "10.")
}

is_private_ip(ip) {
    startswith(ip, "192.168.")
}

is_private_ip(ip) {
    startswith(ip, "172.16.")
}

# Check nếu IP là public/internet
is_public_ip(ip) {
    ip == "0.0.0.0/0"
}

is_public_ip(ip) {
    ip == "::/0"
}

# ============================================
# COMPLIANCE SUMMARY
# ============================================

# Đếm tổng số violations
violation_count = count(deny)

# Đếm tổng số warnings
warning_count = count(warn)

# Overall compliance status
compliance_status = "PASS" {
    violation_count == 0
} else = "FAIL" {
    violation_count > 0
}
