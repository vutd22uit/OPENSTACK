# 🔒 OpenStack Compliance-as-Code

Hệ thống tự động kiểm tra và sửa lỗi bảo mật cho OpenStack theo chuẩn **CIS Benchmark**.

[![Compliance Check](https://github.com/yourusername/compliance-openstack/actions/workflows/check.yml/badge.svg)](https://github.com/yourusername/compliance-openstack/actions)

## 📋 Mục Lục

- [Tổng Quan](#-tổng-quan)
- [Tính Năng](#-tính-năng)
- [CIS Controls](#-cis-controls)
- [Kiến Trúc](#-kiến-trúc)
- [Cài Đặt](#-cài-đặt)
- [Sử Dụng](#-sử-dụng)
- [Demo Workflow](#-demo-workflow)
- [CI/CD Pipeline](#-cicd-pipeline)
- [Dashboard](#-dashboard)
- [Auto-Remediation](#-auto-remediation)
- [Cấu Hình](#-cấu-hình)
- [FAQ](#-faq)

## 🎯 Tổng Quan

**OpenStack Compliance-as-Code** là giải pháp toàn diện để:

✅ **Kiểm tra IaC** - Policy checks cho Terraform code trước khi deploy
✅ **Runtime Scanning** - Quét OpenStack environment định kỳ
✅ **Auto-Remediation** - Tự động sửa các vi phạm có thể
✅ **Dashboard** - Hiển thị compliance score real-time
✅ **CI/CD Integration** - Block PR nếu có violations

## ⚡ Tính Năng

### 1. Pre-Deploy Compliance Gate
- Terraform plan → JSON → OPA/Conftest check
- Block PR nếu vi phạm policies
- Comment tự động với remediation steps

### 2. Runtime Compliance Scanning
- Scan security groups, volumes, instances, networks
- Phát hiện manual changes bypass IaC
- Generate compliance reports (JSON, HTML, Markdown)

### 3. Auto-Remediation
- Tự động xóa dangerous SSH rules
- Add descriptions cho security groups
- Log tất cả remediation actions

### 4. Compliance Dashboard
- Real-time compliance score
- Severity breakdown
- Detailed violation reports
- Evidence với remediation steps

## 🎯 CIS Controls

Project implement **5 CIS OpenStack Benchmark controls**:

| Control | Title | Severity | Auto-Fix |
|---------|-------|----------|----------|
| **CIS-OS-1** | SSH không được mở 0.0.0.0/0 | 🔴 CRITICAL | ✅ Yes |
| **CIS-OS-2** | Default security group không có rule | 🟠 HIGH | ✅ Yes |
| **CIS-OS-3** | Volume phải được encrypt | 🟠 HIGH | ❌ Manual |
| **CIS-OS-4** | Instance không có floating IP không cần thiết | 🟡 MEDIUM | ❌ Manual |
| **CIS-OS-5** | Security group phải có description | 🔵 LOW | ✅ Yes |

## 🏗️ Kiến Trúc

```
┌─────────────────────────────────────────────────────────────┐
│                    DEVELOPER WORKFLOW                        │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  1. IaC PRE-DEPLOY CHECK                                     │
│                                                              │
│  terraform plan → JSON → conftest (OPA Rego)                │
│                     │                                        │
│                     ├─ PASS → Allow Deploy                   │
│                     └─ FAIL → Block PR                       │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  2. RUNTIME SCANNING (Hourly/On-demand)                     │
│                                                              │
│  Python Scanner → OpenStack API → Check Compliance          │
│                                                              │
│  Output: scan_results.json                                  │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  3. AUTO-REMEDIATION                                        │
│                                                              │
│  Read violations → Execute fixes → Log actions              │
│                                                              │
│  - Delete dangerous rules                                   │
│  - Add descriptions                                         │
│  - Log manual action items                                  │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  4. DASHBOARD & REPORTING                                   │
│                                                              │
│  Flask Web UI @ http://localhost:5000                       │
│                                                              │
│  - Compliance Score                                         │
│  - Violations by Severity                                   │
│  - Remediation Steps                                        │
└─────────────────────────────────────────────────────────────┘
```

## 📦 Cài Đặt

### Prerequisites

- Python 3.10+
- Terraform 1.5+
- OpenStack environment với credentials
- Conftest (OPA) - optional cho IaC checks

### 1. Clone Repository

```bash
git clone https://github.com/yourusername/compliance-openstack.git
cd compliance-openstack
```

### 2. Install Python Dependencies

```bash
pip install -r requirements.txt
```

### 3. Install Conftest (cho IaC checks)

```bash
# Linux
wget https://github.com/open-policy-agent/conftest/releases/download/v0.45.0/conftest_0.45.0_Linux_x86_64.tar.gz
tar xzf conftest_0.45.0_Linux_x86_64.tar.gz
sudo mv conftest /usr/local/bin/

# macOS
brew install conftest

# Verify
conftest --version
```

### 4. Configure OpenStack Credentials

**Option 1: Environment Variables (Recommended)**

```bash
export OS_AUTH_URL=http://your-openstack:5000/v3
export OS_PROJECT_NAME=demo
export OS_USERNAME=admin
export OS_PASSWORD=your_password
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_DOMAIN_NAME=Default
export OS_REGION_NAME=RegionOne
```

**Option 2: clouds.yaml**

```yaml
# ~/.config/openstack/clouds.yaml
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
```

## 🚀 Sử Dụng

### 1. IaC Pre-Deploy Check

#### Test Terraform Configuration

```bash
cd terraform

# Initialize Terraform
terraform init

# Create plan
terraform plan -out=plan.binary
terraform show -json plan.binary > plan.json

# Run policy check
conftest test plan.json --policy ../policies/rego/

# Expected output:
# ✅ All checks passed (compliant code)
# ❌ Violations detected (blocked)
```

#### Test với Non-Compliant Code

Uncomment các non-compliant resources trong `terraform/main.tf`:

```hcl
# Uncomment này để test CIS-OS-1 violation
resource "openstack_networking_secgroup_rule_v2" "ssh_open_world" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"  # NGUY HIỂM!
  security_group_id = openstack_networking_secgroup_v2.compliant_sg.id
}
```

Chạy lại policy check:

```bash
terraform plan -out=plan.binary
terraform show -json plan.binary > plan.json
conftest test plan.json --policy ../policies/rego/

# Output sẽ show:
# ❌ BLOCKED [CIS-OS-1]: SSH port 22 open to internet...
```

### 2. Runtime Compliance Scanning

```bash
# Chạy scanner
python scanner/scan.py

# Output:
# 🔍 Starting OpenStack Compliance Scan
# ✅ Connected to OpenStack
# 🔍 [CIS-OS-1] Checking SSH open to world...
# 🔍 [CIS-OS-2] Checking default security group...
# ...
# 📊 COMPLIANCE SCAN SUMMARY
# Compliance Score: 85%
# Total Violations: 3
```

Kết quả được lưu trong `scan_results.json`:

```json
{
  "scan_time": "2025-11-11T10:30:00",
  "compliance_score": 85.0,
  "total_violations": 3,
  "severity_counts": {
    "CRITICAL": 1,
    "HIGH": 1,
    "MEDIUM": 1,
    "LOW": 0
  },
  "violations": [...]
}
```

### 3. Generate Reports

```bash
# Generate HTML and Markdown reports
python scanner/report.py

# Output:
# ✅ Markdown report saved: compliance_report.md
# ✅ HTML report saved: compliance_report.html
```

### 4. Auto-Remediation

#### Dry Run (xem trước actions)

```bash
python remediation/fix.py --dry-run

# Output:
# ⚠️  DRY RUN MODE: No changes will be made
# 🔧 [CIS-OS-1] Fixing SSH open to world...
#    ✅ Would delete dangerous SSH rule abc-123
# ...
```

#### Execute Remediation

```bash
python remediation/fix.py

# ⚠️  WARNING: This will make changes!
# Continue? (yes/no): yes
#
# 🔧 Starting Auto-Remediation
# ✅ Deleted dangerous SSH rule abc-123
# ✅ Added description to SG 'web-sg'
# ⚠️  Volume encryption requires manual action
# ...
# 📊 REMEDIATION SUMMARY
# Total Actions: 5
#   ✅ Successful: 3
#   ⚠️  Manual Review Required: 2
```

Kết quả được lưu trong `remediation_log.json`.

### 5. Launch Dashboard

```bash
python dashboard/app.py

# Output:
# 🚀 Starting OpenStack Compliance Dashboard
# 📊 Dashboard will be available at: http://localhost:5000
```

Mở browser tại `http://localhost:5000` để xem dashboard.

## 🔄 Demo Workflow

### Scenario: Block Non-Compliant Code

```bash
# 1. Developer tạo Terraform code với SSH open to world
cat > terraform/bad_example.tf <<EOF
resource "openstack_networking_secgroup_rule_v2" "bad_ssh" {
  direction         = "ingress"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"  # VIOLATION!
  security_group_id = "sg-123"
}
EOF

# 2. Create PR → GitHub Actions chạy

# 3. Policy check FAIL
terraform plan -out=plan.binary
terraform show -json plan.binary > plan.json
conftest test plan.json --policy policies/rego/

# Output:
# FAIL - 1 violations
# ❌ BLOCKED [CIS-OS-1]: SSH port 22 open to internet

# 4. PR bị block, không thể merge

# 5. Developer fix
# Thay đổi remote_ip_prefix từ "0.0.0.0/0" → "10.0.0.0/8"

# 6. Re-run checks → PASS → Merge được approve
```

### Scenario: Runtime Detection + Auto-Fix

```bash
# 1. Manual change bypass IaC (qua OpenStack CLI/dashboard)
openstack security group rule create \
  --protocol tcp \
  --dst-port 22 \
  --remote-ip 0.0.0.0/0 \
  my-security-group

# 2. Scheduled scanner chạy (hourly)
python scanner/scan.py

# Output:
# ❌ CRITICAL: SSH open to world in SG 'my-security-group'

# 3. Auto-remediation trigger
python remediation/fix.py

# 4. Dangerous rule bị xóa tự động
# Output:
# 🔧 [CIS-OS-1] Fixing SSH open to world...
# ✅ Deleted dangerous SSH rule rule-xyz-789

# 5. Dashboard update với compliance score mới
```

## 🔁 CI/CD Pipeline

### GitHub Actions Workflow

File `.github/workflows/check.yml` define 3 jobs:

#### 1. `terraform-compliance` - Pre-Deploy Check

```yaml
- Terraform init/validate/plan
- Conftest policy check
- Block PR nếu có violations
- Comment PR với remediation steps
```

#### 2. `runtime-scan` - Post-Deploy Verification

```yaml
- Run Python scanner
- Generate reports
- Upload artifacts
- Fail nếu có CRITICAL violations
```

#### 3. `auto-remediation` - Fix Violations

```yaml
- Download scan results
- Run remediation (dry-run)
- Upload remediation log
```

### Setup GitHub Secrets

Trong repository settings, add các secrets:

```
OS_AUTH_URL=http://your-openstack:5000/v3
OS_PROJECT_NAME=demo
OS_USERNAME=admin
OS_PASSWORD=your_password
OS_USER_DOMAIN_NAME=Default
OS_PROJECT_DOMAIN_NAME=Default
```

### Trigger Workflows

- **Automatic**: Mỗi PR hoặc push vào main/master
- **Manual**: Từ GitHub Actions tab → Run workflow

## 📊 Dashboard

Dashboard cung cấp:

### Main Metrics
- **Compliance Score** - % tuân thủ CIS controls
- **Total Violations** - Tổng số vi phạm
- **Checks Passed/Failed** - Kết quả chi tiết

### Severity Breakdown
- 🔴 CRITICAL - Immediate action required
- 🟠 HIGH - Fix within 24 hours
- 🟡 MEDIUM - Fix within 1 week
- 🔵 LOW - Fix during next maintenance

### Violations Detail
- Grouped by control
- Resource information
- Evidence JSON
- Remediation steps

### API Endpoints

```bash
# Get scan results
curl http://localhost:5000/api/scan-results

# Get compliance score
curl http://localhost:5000/api/compliance-score

# Health check
curl http://localhost:5000/health
```

## 🔧 Auto-Remediation

### Supported Auto-Fixes

| Control | Auto-Fix | Description |
|---------|----------|-------------|
| CIS-OS-1 | ✅ Yes | Xóa SSH rules với 0.0.0.0/0 |
| CIS-OS-2 | ✅ Yes | Xóa rules khỏi default SG |
| CIS-OS-5 | ✅ Yes | Add descriptions cho SGs |

### Manual Actions Required

| Control | Reason |
|---------|--------|
| CIS-OS-3 | Volume encryption không thể enable sau khi create |
| CIS-OS-4 | Detaching floating IPs có thể break services |

### Remediation Log

Mỗi action được log trong `remediation_log.json`:

```json
{
  "timestamp": "2025-11-11T11:00:00",
  "dry_run": false,
  "total_actions": 3,
  "actions": [
    {
      "control": "CIS-OS-1",
      "action": "deleted_security_group_rule",
      "resource_id": "rule-123",
      "status": "success",
      "timestamp": "2025-11-11T11:00:01"
    }
  ]
}
```

## ⚙️ Cấu Hình

### config.yaml

File `config.yaml` chứa toàn bộ cấu hình:

```yaml
# Controls definition
controls:
  - id: CIS-OS-1
    severity: CRITICAL
    ...

# Scanning settings
scanning:
  schedule: "0 */6 * * *"  # Every 6 hours
  thresholds:
    compliance_score_minimum: 80

# Remediation settings
remediation:
  auto_remediate:
    enabled: false
    controls: [CIS-OS-1, CIS-OS-5]

# Dashboard settings
dashboard:
  port: 5000
  host: "0.0.0.0"
```

### Terraform Variables

Tạo `terraform/terraform.tfvars`:

```hcl
# OpenStack credentials (hoặc dùng env vars)
# project_name = "demo"
# ...
```

### OPA Policies

Policies trong `policies/rego/security.rego` có thể customize:

```rego
# Add custom policy
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "openstack_compute_instance_v2"

    # Check nếu instance không có metadata
    not resource.change.after.metadata

    msg := "Instance must have metadata tags"
}
```

## 📚 Cấu Trúc Project

```
compliance-openstack/
├── terraform/              # Infrastructure as Code
│   ├── provider.tf        # OpenStack provider config
│   └── main.tf            # Resources definition
├── policies/
│   └── rego/
│       └── security.rego  # OPA policies (5 controls)
├── scanner/
│   ├── scan.py           # Runtime scanner
│   └── report.py         # Report generator
├── remediation/
│   └── fix.py            # Auto-remediation
├── dashboard/
│   ├── app.py            # Flask application
│   └── templates/
│       └── dashboard.html # Web UI
├── .github/workflows/
│   └── check.yml         # CI/CD pipeline
├── config.yaml           # Configuration file
├── requirements.txt      # Python dependencies
└── README.md             # This file
```

## ❓ FAQ

### Q: Làm sao để chạy scanner định kỳ?

**A**: Có 3 options:

1. **Cron job**:
```bash
# Add to crontab
0 */6 * * * cd /path/to/compliance-openstack && python scanner/scan.py
```

2. **systemd timer**:
```bash
# Create /etc/systemd/system/compliance-scan.service
# và /etc/systemd/system/compliance-scan.timer
```

3. **GitHub Actions** (như trong workflow):
```yaml
on:
  schedule:
    - cron: '0 */6 * * *'
```

### Q: Auto-remediation có an toàn không?

**A**:
- ✅ Safe: Xóa dangerous SSH rules, add descriptions
- ⚠️ Caution: Manual review cho default SG changes
- ❌ Not auto: Volume encryption, floating IP detachment

Luôn test với `--dry-run` trước!

### Q: Làm sao customize policies?

**A**: Edit `policies/rego/security.rego`:

```rego
# Example: Deny instances without tags
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "openstack_compute_instance_v2"
    not resource.change.after.metadata.owner
    msg := "Instance must have owner tag"
}
```

### Q: Dashboard có support authentication không?

**A**: Hiện tại không (simple demo). Production nên add:
- Basic auth với Flask-HTTPAuth
- OAuth/SSO integration
- API keys cho API endpoints

### Q: Có thể integrate với Slack/email không?

**A**: Có, trong `config.yaml`:

```yaml
remediation:
  notifications:
    enabled: true
    channels: [slack, email]
    recipients: [security-team@example.com]
```

Cần implement notification logic trong scanner/remediation scripts.

## 🤝 Contributing

Contributions welcome! Please:

1. Fork repository
2. Create feature branch
3. Add tests
4. Submit pull request

## 📝 License

MIT License - xem [LICENSE](LICENSE) file.

## 📧 Contact

- **Author**: Your Name
- **Email**: your.email@example.com
- **Issues**: https://github.com/yourusername/compliance-openstack/issues

## 🙏 Acknowledgments

- [CIS Benchmarks](https://www.cisecurity.org/benchmark/openstack)
- [Open Policy Agent](https://www.openpolicyagent.org/)
- [OpenStack Security Guide](https://docs.openstack.org/security-guide/)
- [Terraform OpenStack Provider](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest)

---

**⭐ Nếu project này hữu ích, hãy star repo!**

**Made with ❤️ for OpenStack Security**
