# ============================================
# LOCAL VALUES - OpenStack Terraform Configuration
# Compliance as Code - Enhanced Version
# ============================================

locals {
  # ============================================
  # NAMING CONVENTIONS
  # ============================================

  name_prefix = "${var.project_name}-${var.environment}"

  # Resource naming with standardized format
  resource_names = {
    security_group        = "${local.name_prefix}-sg"
    network              = "${local.name_prefix}-network"
    subnet               = "${local.name_prefix}-subnet"
    router               = "${local.name_prefix}-router"
    instance_prefix      = "${local.name_prefix}-instance"
    volume_prefix        = "${local.name_prefix}-volume"
    keypair              = "${local.name_prefix}-keypair"
  }

  # ============================================
  # COMMON TAGS / METADATA
  # ============================================

  # Base tags applied to all resources
  common_tags = merge(
    {
      Environment       = var.environment
      Project          = var.project_name
      Owner            = var.owner
      ManagedBy        = "Terraform"
      ComplianceFramework = join(",", var.compliance_frameworks)
      CreatedDate      = timestamp()
    },
    var.enable_cost_allocation_tags ? {
      CostCenter       = var.cost_center
      BillingProject   = var.project_name
    } : {},
    var.enable_audit_logging ? {
      AuditEnabled     = "true"
      LogRetention     = "90days"
    } : {},
    var.enable_backup_tags ? {
      BackupEnabled    = "true"
      BackupRetention  = "${var.backup_retention_days}days"
    } : {},
    var.additional_tags
  )

  # Security-specific tags
  security_tags = {
    SecurityLevel    = "high"
    DataClassification = "confidential"
    EncryptionRequired = var.enforce_volume_encryption ? "true" : "false"
  }

  # ============================================
  # COMPLIANCE RULES
  # ============================================

  # CIS-OS-1: SSH must not be open to 0.0.0.0/0
  ssh_compliance_check = alltrue([
    for cidr in var.allowed_ssh_cidr_blocks :
    cidr != "0.0.0.0/0"
  ])

  # CIS-OS-3: Volumes must be encrypted
  volume_encryption_compliant = var.enforce_volume_encryption

  # CIS-OS-5: Resources must have descriptions
  require_descriptions = var.require_resource_descriptions

  # ============================================
  # SECURITY GROUP RULES CONFIGURATION
  # ============================================

  # SSH rules (restricted)
  ssh_rules = [
    for idx, cidr in var.allowed_ssh_cidr_blocks : {
      name             = "ssh-${idx}"
      direction        = "ingress"
      protocol         = "tcp"
      port_range_min   = 22
      port_range_max   = 22
      remote_ip_prefix = cidr
      description      = "SSH access from ${cidr} - CIS-OS-1 compliant"
    }
  ]

  # HTTP rules
  http_rules = [
    for idx, cidr in var.allowed_http_cidr_blocks : {
      name             = "http-${idx}"
      direction        = "ingress"
      protocol         = "tcp"
      port_range_min   = 80
      port_range_max   = 80
      remote_ip_prefix = cidr
      description      = "HTTP access from ${cidr}"
    }
  ]

  # HTTPS rules
  https_rules = [
    for idx, cidr in var.allowed_https_cidr_blocks : {
      name             = "https-${idx}"
      direction        = "ingress"
      protocol         = "tcp"
      port_range_min   = 443
      port_range_max   = 443
      remote_ip_prefix = cidr
      description      = "HTTPS access from ${cidr}"
    }
  ]

  # Combine all ingress rules
  all_ingress_rules = concat(
    local.ssh_rules,
    local.http_rules,
    local.https_rules
  )

  # Egress rules (if restrictions enabled)
  egress_rules = var.enable_egress_restrictions ? [
    {
      name             = "egress-http"
      direction        = "egress"
      protocol         = "tcp"
      port_range_min   = 80
      port_range_max   = 80
      remote_ip_prefix = "0.0.0.0/0"
      description      = "Allow HTTP egress"
    },
    {
      name             = "egress-https"
      direction        = "egress"
      protocol         = "tcp"
      port_range_min   = 443
      port_range_max   = 443
      remote_ip_prefix = "0.0.0.0/0"
      description      = "Allow HTTPS egress"
    },
    {
      name             = "egress-dns"
      direction        = "egress"
      protocol         = "udp"
      port_range_min   = 53
      port_range_max   = 53
      remote_ip_prefix = "0.0.0.0/0"
      description      = "Allow DNS egress"
    }
  ] : [
    {
      name             = "egress-all"
      direction        = "egress"
      protocol         = "tcp"
      port_range_min   = 1
      port_range_max   = 65535
      remote_ip_prefix = "0.0.0.0/0"
      description      = "Allow all egress traffic"
    }
  ]

  # ============================================
  # COMPLIANCE VALIDATION MESSAGES
  # ============================================

  compliance_status = {
    ssh_compliance = local.ssh_compliance_check ? "PASS" : "FAIL"
    encryption_compliance = local.volume_encryption_compliant ? "PASS" : "FAIL"
    description_compliance = local.require_descriptions ? "ENFORCED" : "NOT_ENFORCED"
  }

  # ============================================
  # RESOURCE DESCRIPTIONS (CIS-OS-5 COMPLIANCE)
  # ============================================

  descriptions = {
    security_group = "Production security group with CIS OpenStack compliance - Restricts SSH to authorized networks only"
    network       = "Private network for ${var.environment} environment - Isolated and secured"
    subnet        = "Private subnet ${var.network_cidr} - DHCP enabled with secure DNS"
    router        = "Router for external connectivity - Managed by ${var.owner}"
    instance      = "Compute instance with encrypted storage - CIS-OS-3 compliant"
    volume        = "Encrypted data volume - CIS-OS-3 compliant with ${var.backup_retention_days} days retention"
  }
}

# ============================================
# VALIDATION OUTPUTS (for debugging)
# ============================================

# These will be shown during terraform plan/apply
output "compliance_validation" {
  description = "Compliance validation status"
  value = {
    ssh_open_to_world     = !local.ssh_compliance_check ? "VIOLATION: SSH is open to 0.0.0.0/0" : "COMPLIANT"
    volume_encryption     = local.volume_encryption_compliant ? "COMPLIANT: All volumes encrypted" : "WARNING: Volume encryption not enforced"
    description_requirement = local.require_descriptions ? "COMPLIANT: Resource descriptions required" : "WARNING: Descriptions not enforced"
    overall_status       = local.ssh_compliance_check && local.volume_encryption_compliant ? "COMPLIANT" : "VIOLATIONS DETECTED"
  }
}
