#!/bin/bash
# Demo Script cho OpenStack Compliance-as-Code
# Chạy script này để test toàn bộ workflow

set -e

echo "=============================================="
echo "🚀 OpenStack Compliance-as-Code Demo"
echo "=============================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check dependencies
echo "📋 Checking dependencies..."

if ! command -v python3 &> /dev/null; then
    echo -e "${RED}❌ Python 3 not found${NC}"
    exit 1
fi

if ! command -v terraform &> /dev/null; then
    echo -e "${YELLOW}⚠️  Terraform not found (optional for IaC checks)${NC}"
fi

if ! command -v conftest &> /dev/null; then
    echo -e "${YELLOW}⚠️  Conftest not found (optional for IaC checks)${NC}"
fi

echo -e "${GREEN}✅ Dependencies OK${NC}"
echo ""

# Check OpenStack credentials
echo "🔑 Checking OpenStack credentials..."

if [ -z "$OS_AUTH_URL" ]; then
    echo -e "${YELLOW}⚠️  OpenStack credentials not set${NC}"
    echo "Please set environment variables:"
    echo "  export OS_AUTH_URL=http://your-openstack:5000/v3"
    echo "  export OS_PROJECT_NAME=demo"
    echo "  export OS_USERNAME=admin"
    echo "  export OS_PASSWORD=secret"
    echo ""
    echo "Or create ~/.config/openstack/clouds.yaml"
    echo ""
    echo "Continuing with demo mode (some features may not work)..."
else
    echo -e "${GREEN}✅ OpenStack credentials found${NC}"
fi
echo ""

# Install Python dependencies
echo "📦 Installing Python dependencies..."
pip install -q -r requirements.txt
echo -e "${GREEN}✅ Dependencies installed${NC}"
echo ""

# Demo 1: IaC Policy Check
echo "=============================================="
echo "📝 DEMO 1: Terraform Policy Check"
echo "=============================================="
echo ""

if command -v terraform &> /dev/null && command -v conftest &> /dev/null; then
    cd terraform

    echo "Initializing Terraform..."
    terraform init -upgrade > /dev/null 2>&1 || true

    echo "Creating Terraform plan..."
    terraform plan -out=plan.binary > /dev/null 2>&1 || true
    terraform show -json plan.binary > plan.json 2>&1 || true

    if [ -f plan.json ]; then
        echo "Running policy checks..."
        echo ""

        if conftest test plan.json --policy ../policies/rego/; then
            echo -e "${GREEN}✅ All policy checks PASSED${NC}"
        else
            echo -e "${RED}❌ Policy violations detected${NC}"
            echo "This is expected if you have non-compliant resources"
        fi
    else
        echo -e "${YELLOW}⚠️  Could not create Terraform plan (OpenStack connection required)${NC}"
    fi

    cd ..
else
    echo -e "${YELLOW}⚠️  Terraform or Conftest not installed, skipping IaC checks${NC}"
fi
echo ""

# Demo 2: Runtime Scanning
echo "=============================================="
echo "📊 DEMO 2: Runtime Compliance Scanning"
echo "=============================================="
echo ""

if [ -n "$OS_AUTH_URL" ]; then
    echo "Running compliance scanner..."
    python scanner/scan.py || true

    if [ -f scan_results.json ]; then
        echo ""
        echo -e "${GREEN}✅ Scan completed${NC}"
        echo ""
        echo "Results summary:"
        python -c "
import json
with open('scan_results.json', 'r') as f:
    data = json.load(f)
    print(f\"  Compliance Score: {data['compliance_score']}%\")
    print(f\"  Total Violations: {data['total_violations']}\")
    print(f\"  - CRITICAL: {data['severity_counts']['CRITICAL']}\")
    print(f\"  - HIGH: {data['severity_counts']['HIGH']}\")
    print(f\"  - MEDIUM: {data['severity_counts']['MEDIUM']}\")
    print(f\"  - LOW: {data['severity_counts']['LOW']}\")
" 2>/dev/null || echo "Could not parse results"
    fi
else
    echo -e "${YELLOW}⚠️  OpenStack credentials not set, creating mock scan results...${NC}"

    cat > scan_results.json <<'EOF'
{
  "scan_time": "2025-11-11T10:00:00",
  "compliance_score": 80.0,
  "total_violations": 2,
  "severity_counts": {
    "CRITICAL": 1,
    "HIGH": 0,
    "MEDIUM": 1,
    "LOW": 0
  },
  "violations": [
    {
      "control": "CIS-OS-1",
      "title": "SSH Open to Internet",
      "severity": "CRITICAL",
      "resource_type": "security_group_rule",
      "resource_id": "demo-rule-123",
      "security_group_name": "demo-sg",
      "description": "SSH port 22 is open to 0.0.0.0/0 (DEMO DATA)",
      "remediation": "Remove or restrict SSH rule to specific IP ranges",
      "evidence": {
        "rule_id": "demo-rule-123",
        "protocol": "tcp",
        "port": 22,
        "remote_ip": "0.0.0.0/0"
      },
      "timestamp": "2025-11-11T10:00:00"
    },
    {
      "control": "CIS-OS-4",
      "title": "Floating IP Attached",
      "severity": "MEDIUM",
      "resource_type": "floating_ip",
      "resource_id": "demo-fip-456",
      "description": "Floating IP 203.0.113.10 attached to instance (DEMO DATA)",
      "remediation": "Review if public access is necessary",
      "evidence": {
        "floating_ip": "203.0.113.10",
        "fixed_ip": "10.0.0.5"
      },
      "timestamp": "2025-11-11T10:00:00"
    }
  ],
  "summary": {
    "total_checks": 5,
    "passed_checks": 4,
    "failed_checks": 1
  }
}
EOF
    echo -e "${GREEN}✅ Mock scan results created${NC}"
fi
echo ""

# Demo 3: Generate Reports
echo "=============================================="
echo "📄 DEMO 3: Generate Reports"
echo "=============================================="
echo ""

if [ -f scan_results.json ]; then
    echo "Generating reports..."
    python scanner/report.py
    echo ""
    echo -e "${GREEN}✅ Reports generated:${NC}"
    echo "  - compliance_report.md"
    echo "  - compliance_report.html"
else
    echo -e "${YELLOW}⚠️  No scan results found, skipping report generation${NC}"
fi
echo ""

# Demo 4: Auto-Remediation (Dry Run)
echo "=============================================="
echo "🔧 DEMO 4: Auto-Remediation (Dry Run)"
echo "=============================================="
echo ""

if [ -f scan_results.json ]; then
    echo "Running auto-remediation in DRY RUN mode..."
    echo "(No actual changes will be made)"
    echo ""
    python remediation/fix.py --dry-run || true
else
    echo -e "${YELLOW}⚠️  No scan results found, skipping remediation${NC}"
fi
echo ""

# Demo 5: Dashboard
echo "=============================================="
echo "🌐 DEMO 5: Launch Dashboard"
echo "=============================================="
echo ""

echo "Starting Flask dashboard..."
echo ""
echo -e "${GREEN}Dashboard will be available at:${NC}"
echo "  http://localhost:5000"
echo ""
echo "Press Ctrl+C to stop the dashboard"
echo ""

python dashboard/app.py
