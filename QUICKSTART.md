# 🚀 Quick Start Guide

Hướng dẫn nhanh để chạy OpenStack Compliance-as-Code trong 5 phút.

## 📋 Prerequisites

```bash
# Check Python version (cần >= 3.10)
python3 --version

# Check nếu có OpenStack access
echo $OS_AUTH_URL
```

## ⚡ Quick Setup

### 1. Install Dependencies

```bash
pip install -r requirements.txt
```

### 2. Configure OpenStack Credentials

**Option A: Environment Variables**

```bash
export OS_AUTH_URL=http://your-openstack:5000/v3
export OS_PROJECT_NAME=demo
export OS_USERNAME=admin
export OS_PASSWORD=your_password
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_DOMAIN_NAME=Default
```

**Option B: Create clouds.yaml**

```bash
mkdir -p ~/.config/openstack
cat > ~/.config/openstack/clouds.yaml <<EOF
clouds:
  openstack:
    auth:
      auth_url: http://controller:5000/v3
      project_name: demo
      username: admin
      password: secret
      user_domain_name: Default
      project_domain_name: Default
    region_name: RegionOne
EOF
```

### 3. Run Compliance Scanner

```bash
python scanner/scan.py
```

Kết quả sẽ show:
```
🔍 Starting OpenStack Compliance Scan
✅ Connected to OpenStack
...
📊 COMPLIANCE SCAN SUMMARY
Compliance Score: 85%
Total Violations: 3
```

### 4. View Dashboard

```bash
python dashboard/app.py
```

Mở browser: http://localhost:5000

### 5. (Optional) Run Demo Script

```bash
chmod +x demo.sh
./demo.sh
```

Script sẽ tự động chạy tất cả các bước demo.

## 🎯 Test Scenarios

### Scenario 1: Test IaC Policy Check

```bash
cd terraform

# Initialize
terraform init

# Create plan
terraform plan -out=plan.binary
terraform show -json plan.binary > plan.json

# Check policies
conftest test plan.json --policy ../policies/rego/

# Expected: ✅ PASS (compliant resources)
```

### Scenario 2: Test Non-Compliant Code

Edit `terraform/main.tf`, uncomment:

```hcl
resource "openstack_networking_secgroup_rule_v2" "ssh_open_world" {
  direction         = "ingress"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"  # VIOLATION!
  security_group_id = openstack_networking_secgroup_v2.compliant_sg.id
}
```

Chạy lại:

```bash
terraform plan -out=plan.binary
terraform show -json plan.binary > plan.json
conftest test plan.json --policy ../policies/rego/

# Expected: ❌ FAIL - SSH open to world detected
```

### Scenario 3: Auto-Remediation

```bash
# Dry run (xem trước, không thực hiện)
python remediation/fix.py --dry-run

# Execute (sau khi confirm)
python remediation/fix.py
# Enter 'yes' to confirm
```

## 📊 Understanding Results

### Compliance Score

- **90-100%**: Excellent - minimal issues
- **70-89%**: Good - some improvements needed
- **< 70%**: Critical - immediate action required

### Severity Levels

- 🔴 **CRITICAL**: Fix immediately (SSH open to world)
- 🟠 **HIGH**: Fix within 24h (unencrypted volumes)
- 🟡 **MEDIUM**: Fix within 1 week (unnecessary floating IPs)
- 🔵 **LOW**: Fix during maintenance (missing descriptions)

## 🔧 Common Issues

### Issue: Cannot connect to OpenStack

```bash
# Check credentials
env | grep OS_

# Test connection
openstack server list

# If using clouds.yaml, check:
cat ~/.config/openstack/clouds.yaml
```

### Issue: Python dependencies fail

```bash
# Use virtual environment
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### Issue: Terraform init fails

```bash
# Remove lock file
rm -rf terraform/.terraform*

# Re-initialize
cd terraform
terraform init -upgrade
```

### Issue: Dashboard shows "No scan results"

```bash
# Run scanner first
python scanner/scan.py

# Check if file exists
ls -lh scan_results.json

# Then start dashboard
python dashboard/app.py
```

## 📚 Next Steps

1. **Customize Policies**: Edit `policies/rego/security.rego`
2. **Add Controls**: Update `config.yaml`
3. **Setup CI/CD**: Configure GitHub Actions secrets
4. **Schedule Scanning**: Setup cron job
5. **Enable Auto-Remediation**: Update `config.yaml`

## 💡 Tips

- Always run `--dry-run` trước khi remediate
- Review scan results trước khi auto-fix
- Backup quan trọng trước khi thay đổi
- Test policies trên non-prod environment trước
- Monitor dashboard sau mỗi deployment

## 🆘 Getting Help

- 📖 Full docs: [README.md](README.md)
- 🐛 Issues: GitHub Issues
- 💬 Questions: Check FAQ trong README

## 🎉 You're Ready!

Project đã sẵn sàng sử dụng. Start với:

```bash
# 1. Run scanner
python scanner/scan.py

# 2. View dashboard
python dashboard/app.py

# 3. Check compliance score at http://localhost:5000
```

Happy compliance checking! 🔒
