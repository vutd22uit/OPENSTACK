# OpenStack Terraform - Compliance as Code (Enhanced)

Enterprise-grade OpenStack infrastructure with built-in compliance checks and security best practices.

## Features

### Compliance Frameworks
- **CIS OpenStack Benchmark** - Industry security standards
- **ISO-27001** - Information security management
- **SOC2** - Service organization controls

### Security Controls

#### CIS-OS-1: SSH Access Restrictions
- SSH access must NOT be open to 0.0.0.0/0
- Restricted to specific CIDR blocks only
- Automatic validation during plan/apply

#### CIS-OS-3: Volume Encryption
- All volumes encrypted at rest
- Boot volumes and data volumes
- Enforced by default

#### CIS-OS-5: Resource Descriptions
- All resources require descriptions
- Improves audit trail and documentation
- Mandatory for compliance

#### CIS-OS-7: Network Isolation
- Private network with proper CIDR allocation
- Reserved IP ranges for infrastructure
- Secure DNS configuration

#### CIS-OS-9: Audit Logging & Tagging
- Comprehensive metadata on all resources
- Cost allocation tags
- Backup retention tags
- Environment and owner tracking

### Advanced Features

- **Egress Traffic Control**: Optional restriction of outbound traffic
- **Dynamic Security Rules**: Configurable via variables
- **Lifecycle Management**: Prevent accidental deletions
- **Volume Attachments**: Automatic data volume mounting
- **Compliance Validation**: Real-time checks during terraform plan
- **Comprehensive Outputs**: Detailed compliance and security reports

## File Structure

```
terraform/
├── main.tf                    # Main infrastructure resources
├── variables.tf               # Variable definitions with validations
├── locals.tf                  # Local values, naming, and tags
├── outputs.tf                 # Comprehensive outputs
├── provider.tf                # OpenStack provider configuration
├── terraform.tfvars.example   # Example configuration
└── README.md                  # This file
```

## Prerequisites

1. **Terraform** >= 1.0
2. **OpenStack** credentials configured
3. **OpenStack Provider** ~> 1.54.0

## Quick Start

### 1. Configure OpenStack Credentials

```bash
export OS_AUTH_URL="https://your-openstack:5000/v3"
export OS_PROJECT_NAME="your-project"
export OS_USERNAME="your-username"
export OS_PASSWORD="your-password"
export OS_REGION_NAME="RegionOne"
export OS_USER_DOMAIN_NAME="Default"
export OS_PROJECT_DOMAIN_NAME="Default"
```

### 2. Create Configuration File

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

### 3. Initialize Terraform

```bash
cd terraform
terraform init
```

### 4. Validate Configuration

```bash
terraform validate
terraform fmt -check
```

### 5. Plan and Review

```bash
terraform plan
```

**Important**: Review the compliance validation output:
- Check for any CIS violations
- Review security recommendations
- Verify resource configurations

### 6. Apply Configuration

```bash
terraform apply
```

## Configuration Guide

### Basic Configuration

Minimum required variables in `terraform.tfvars`:

```hcl
environment  = "production"
project_name = "my-project"
owner        = "my-team"

# SSH CIDR blocks - MUST NOT include 0.0.0.0/0
allowed_ssh_cidr_blocks = ["192.168.1.0/24"]
```

### Security Configuration

```hcl
# Enable all security features
enforce_volume_encryption     = true
enable_egress_restrictions    = true
enable_audit_logging          = true
require_resource_descriptions = true
```

### Compute Configuration

```hcl
instance_count            = 2
instance_flavor           = "m1.small"
instance_image            = "Ubuntu 22.04"
instance_boot_volume_size = 20
```

### Storage Configuration

```hcl
create_data_volumes        = true
data_volume_count          = 2
data_volume_size           = 10
enforce_volume_encryption  = true
```

## Compliance Validation

The configuration automatically validates compliance during `terraform plan`:

### SSH Access Check (CIS-OS-1)
```
✅ PASS: SSH restricted to authorized networks
❌ FAIL: SSH is open to 0.0.0.0/0 (blocks apply)
```

### Volume Encryption (CIS-OS-3)
```
✅ PASS: All volumes encrypted
⚠️  WARNING: Volume encryption not enforced
```

### Resource Descriptions (CIS-OS-5)
```
✅ COMPLIANT: All resources have descriptions
```

## Outputs

After applying, you'll get comprehensive outputs:

### Compliance Summary
```hcl
compliance_summary = {
  cis_compliance = {
    cis_os_1 = { control = "SSH Access", status = "COMPLIANT" }
    cis_os_3 = { control = "Encryption", status = "COMPLIANT" }
    ...
  }
  overall_status = "FULLY COMPLIANT"
}
```

### Security Recommendations
```
security_recommendations = [
  "✅ All security best practices enabled"
]
```

### Resource Details
```hcl
resource_summary = {
  resources_created = {
    networks        = 1
    instances       = 2
    data_volumes    = 2
    ...
  }
}
```

## Best Practices

### For Production

1. **Enable All Security Features**
   ```hcl
   enforce_volume_encryption     = true
   enable_egress_restrictions    = true
   enable_audit_logging          = true
   enable_backup_tags            = true
   ```

2. **Restrict Network Access**
   ```hcl
   allowed_ssh_cidr_blocks = [
     "192.168.1.0/24",  # Admin network only
   ]
   ```

3. **Use Appropriate Instance Sizing**
   ```hcl
   instance_flavor = "m1.medium"  # For production workloads
   ```

4. **Enable Cost Tracking**
   ```hcl
   enable_cost_allocation_tags = true
   cost_center = "IT-SEC-001"
   ```

### For Development

1. **Relaxed Settings (with caution)**
   ```hcl
   environment = "dev"
   instance_count = 1
   instance_flavor = "m1.tiny"
   enable_egress_restrictions = false
   ```

2. **Still Maintain Security Basics**
   ```hcl
   # Still restrict SSH even in dev
   allowed_ssh_cidr_blocks = ["10.0.0.0/8"]

   # Always encrypt volumes
   enforce_volume_encryption = true
   ```

## Common Operations

### Scale Instances

```hcl
# In terraform.tfvars
instance_count = 5  # Scale to 5 instances
```

Then:
```bash
terraform apply
```

### Add Data Volumes

```hcl
# In terraform.tfvars
data_volume_count = 3
data_volume_size  = 50
```

### Update Security Rules

```hcl
# In terraform.tfvars
allowed_https_cidr_blocks = [
  "10.0.0.0/8",
  "172.16.0.0/12"
]
```

### Change Environment

```hcl
# In terraform.tfvars
environment = "staging"
```

This will update all resource names and tags automatically.

## Troubleshooting

### SSH Compliance Violation

**Error**: `CIS-OS-1 VIOLATION - SSH is open to 0.0.0.0/0`

**Solution**: Update `allowed_ssh_cidr_blocks` to specific CIDR ranges:
```hcl
allowed_ssh_cidr_blocks = ["192.168.1.0/24"]
```

### Volume Encryption Warning

**Warning**: `CIS-OS-3 - Volume encryption is not enforced`

**Solution**: Enable encryption:
```hcl
enforce_volume_encryption = true
```

### Provider Timeout

**Error**: Timeout querying OpenStack resources

**Solution**: Already configured with retries in `provider.tf`:
```hcl
max_retries = 3
timeout     = 30
```

### Image Not Found

**Error**: Image "Ubuntu 22.04" not found

**Solution**: Update to available image name:
```bash
openstack image list
```

Then update:
```hcl
instance_image = "Ubuntu-22.04-LTS"
```

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

**Warning**: This will delete all resources including:
- Compute instances
- Volumes (data will be lost)
- Networks and security groups

## Security Considerations

### Never Commit Secrets

Add to `.gitignore`:
```
terraform.tfvars
*.tfstate
*.tfstate.backup
.terraform/
```

### Use Separate Environments

Maintain separate state files for each environment:
```bash
terraform workspace new production
terraform workspace new staging
terraform workspace new dev
```

### Regular Compliance Audits

Run compliance checks regularly:
```bash
terraform plan | grep -A 20 "compliance"
```

### Backup State Files

Always backup your terraform state:
```bash
# Remote state backend recommended
terraform {
  backend "s3" {
    # Configure remote backend
  }
}
```

## Compliance Checklist

Before deploying to production:

- [ ] SSH restricted to specific CIDR blocks (not 0.0.0.0/0)
- [ ] All volumes encrypted (`enforce_volume_encryption = true`)
- [ ] Resource descriptions enabled
- [ ] Audit logging enabled
- [ ] Backup tags configured
- [ ] Egress restrictions enabled (recommended)
- [ ] Cost allocation tags configured
- [ ] Appropriate instance sizing
- [ ] DNS properly configured
- [ ] Security groups reviewed and approved

## Support & Contribution

For issues or improvements:
1. Review the compliance validation output
2. Check terraform plan for warnings
3. Verify OpenStack provider version
4. Check OpenStack API connectivity

## License

This configuration is provided as-is for infrastructure management.

## Version History

- **v2.0** - Complete rewrite with enhanced compliance
  - Added comprehensive CIS OpenStack controls
  - Improved variable validation
  - Enhanced outputs and reporting
  - Better code organization
  - Production-grade structure

- **v1.0** - Initial version
  - Basic OpenStack resources
  - Simple compliance checks
