#!/usr/bin/env python3
"""
OpenStack Compliance Scanner
Quét runtime OpenStack environment để tìm vi phạm CIS Benchmark
"""

import os
import sys
import json
from datetime import datetime
from typing import List, Dict, Any

try:
    from openstack import connect
    from openstack.exceptions import OpenStackCloudException
except ImportError:
    print("❌ Error: openstacksdk not installed. Run: pip install openstacksdk")
    sys.exit(1)

# Load config
import yaml

class ComplianceScanner:
    """Scanner để kiểm tra compliance trên OpenStack runtime"""

    def __init__(self, cloud_name: str = 'openstack'):
        """
        Khởi tạo scanner

        Args:
            cloud_name: Tên cloud trong clouds.yaml hoặc dùng env vars
        """
        try:
            self.conn = connect(cloud=cloud_name)
            print(f"✅ Connected to OpenStack: {cloud_name}")
        except Exception as e:
            print(f"❌ Failed to connect to OpenStack: {e}")
            print("\n💡 Ensure you have set environment variables:")
            print("   - OS_AUTH_URL")
            print("   - OS_PROJECT_NAME")
            print("   - OS_USERNAME")
            print("   - OS_PASSWORD")
            sys.exit(1)

        self.violations = []
        self.scan_time = datetime.now().isoformat()

        # Load config
        self.load_config()

    def load_config(self):
        """Load config từ config.yaml"""
        config_path = os.path.join(os.path.dirname(__file__), '..', 'config.yaml')

        if os.path.exists(config_path):
            with open(config_path, 'r') as f:
                self.config = yaml.safe_load(f)
                print(f"✅ Loaded config from {config_path}")
        else:
            print(f"⚠️  Config file not found at {config_path}, using defaults")
            self.config = {}

    def scan_all(self) -> Dict[str, Any]:
        """
        Chạy tất cả các compliance checks

        Returns:
            Dictionary chứa kết quả scan
        """
        print("\n" + "="*60)
        print("🔍 Starting OpenStack Compliance Scan")
        print("="*60 + "\n")

        # Run all checks
        self.check_cis_os_1_ssh_open_world()
        self.check_cis_os_2_default_sg_rules()
        self.check_cis_os_3_volume_encryption()
        self.check_cis_os_4_floating_ips()
        self.check_cis_os_5_sg_descriptions()

        # Generate summary
        return self.generate_report()

    def check_cis_os_1_ssh_open_world(self):
        """
        CIS-OS-1: Kiểm tra SSH không được mở 0.0.0.0/0
        """
        print("🔍 [CIS-OS-1] Checking SSH open to world...")

        try:
            for sg in self.conn.network.security_groups():
                # Get rules cho security group này
                rules = list(self.conn.network.security_group_rules(
                    security_group_id=sg.id
                ))

                for rule in rules:
                    # Check SSH port 22 và open to world
                    if (rule.protocol == 'tcp' and
                        rule.port_range_min == 22 and
                        rule.remote_ip_prefix == '0.0.0.0/0'):

                        self.violations.append({
                            'control': 'CIS-OS-1',
                            'title': 'SSH Open to Internet',
                            'severity': 'CRITICAL',
                            'resource_type': 'security_group_rule',
                            'resource_id': rule.id,
                            'security_group_id': sg.id,
                            'security_group_name': sg.name,
                            'description': f'SSH port 22 is open to 0.0.0.0/0 in security group "{sg.name}"',
                            'remediation': 'Remove or restrict SSH rule to specific IP ranges',
                            'evidence': {
                                'rule_id': rule.id,
                                'protocol': rule.protocol,
                                'port': rule.port_range_min,
                                'remote_ip': rule.remote_ip_prefix,
                                'direction': rule.direction
                            },
                            'timestamp': self.scan_time
                        })

                        print(f"   ❌ CRITICAL: SSH open to world in SG '{sg.name}' (rule: {rule.id})")

            print(f"   ✅ CIS-OS-1 check completed\n")

        except Exception as e:
            print(f"   ⚠️  Error checking CIS-OS-1: {e}\n")

    def check_cis_os_2_default_sg_rules(self):
        """
        CIS-OS-2: Kiểm tra default security group không có rules
        """
        print("🔍 [CIS-OS-2] Checking default security group...")

        try:
            for sg in self.conn.network.security_groups():
                if sg.name == 'default':
                    # Get rules
                    rules = list(self.conn.network.security_group_rules(
                        security_group_id=sg.id
                    ))

                    # Filter out default egress rules (cho phép outbound)
                    custom_rules = [r for r in rules if not (
                        r.direction == 'egress' and
                        r.remote_ip_prefix in ['0.0.0.0/0', None]
                    )]

                    if custom_rules:
                        self.violations.append({
                            'control': 'CIS-OS-2',
                            'title': 'Default Security Group Has Custom Rules',
                            'severity': 'HIGH',
                            'resource_type': 'security_group',
                            'resource_id': sg.id,
                            'security_group_name': sg.name,
                            'description': f'Default security group has {len(custom_rules)} custom rule(s)',
                            'remediation': 'Remove all custom rules from default security group',
                            'evidence': {
                                'sg_id': sg.id,
                                'total_rules': len(rules),
                                'custom_rules': len(custom_rules),
                                'rule_ids': [r.id for r in custom_rules]
                            },
                            'timestamp': self.scan_time
                        })

                        print(f"   ❌ HIGH: Default SG has {len(custom_rules)} custom rule(s)")

            print(f"   ✅ CIS-OS-2 check completed\n")

        except Exception as e:
            print(f"   ⚠️  Error checking CIS-OS-2: {e}\n")

    def check_cis_os_3_volume_encryption(self):
        """
        CIS-OS-3: Kiểm tra volumes có được encrypt không
        """
        print("🔍 [CIS-OS-3] Checking volume encryption...")

        try:
            volumes = list(self.conn.block_storage.volumes())

            for volume in volumes:
                # Check nếu volume không được encrypt
                if not volume.is_encrypted:
                    self.violations.append({
                        'control': 'CIS-OS-3',
                        'title': 'Volume Not Encrypted',
                        'severity': 'HIGH',
                        'resource_type': 'volume',
                        'resource_id': volume.id,
                        'resource_name': volume.name or 'unnamed',
                        'description': f'Volume "{volume.name or volume.id}" is not encrypted',
                        'remediation': 'Enable encryption for all new volumes. Existing volumes may need to be recreated with encryption',
                        'evidence': {
                            'volume_id': volume.id,
                            'volume_name': volume.name,
                            'size': volume.size,
                            'encrypted': volume.is_encrypted,
                            'status': volume.status
                        },
                        'timestamp': self.scan_time
                    })

                    print(f"   ❌ HIGH: Unencrypted volume '{volume.name or volume.id}' ({volume.size}GB)")

            print(f"   ✅ CIS-OS-3 check completed ({len(volumes)} volumes scanned)\n")

        except Exception as e:
            print(f"   ⚠️  Error checking CIS-OS-3: {e}\n")

    def check_cis_os_4_floating_ips(self):
        """
        CIS-OS-4: Kiểm tra floating IPs không cần thiết
        """
        print("🔍 [CIS-OS-4] Checking floating IPs...")

        try:
            floating_ips = list(self.conn.network.ips())

            for fip in floating_ips:
                # Warn về mọi floating IP được attach
                if fip.fixed_ip_address:
                    self.violations.append({
                        'control': 'CIS-OS-4',
                        'title': 'Floating IP Attached to Instance',
                        'severity': 'MEDIUM',
                        'resource_type': 'floating_ip',
                        'resource_id': fip.id,
                        'description': f'Floating IP {fip.floating_ip_address} attached to {fip.fixed_ip_address}',
                        'remediation': 'Verify if public access is necessary. Use bastion/VPN instead if possible',
                        'evidence': {
                            'floating_ip': fip.floating_ip_address,
                            'fixed_ip': fip.fixed_ip_address,
                            'port_id': fip.port_id,
                            'status': fip.status
                        },
                        'timestamp': self.scan_time
                    })

                    print(f"   ⚠️  MEDIUM: Floating IP {fip.floating_ip_address} → {fip.fixed_ip_address}")

            print(f"   ✅ CIS-OS-4 check completed ({len(floating_ips)} floating IPs found)\n")

        except Exception as e:
            print(f"   ⚠️  Error checking CIS-OS-4: {e}\n")

    def check_cis_os_5_sg_descriptions(self):
        """
        CIS-OS-5: Kiểm tra security groups có description
        """
        print("🔍 [CIS-OS-5] Checking security group descriptions...")

        try:
            for sg in self.conn.network.security_groups():
                # Skip default security group
                if sg.name == 'default':
                    continue

                # Check nếu không có description hoặc quá ngắn
                if not sg.description or len(sg.description) < 10:
                    self.violations.append({
                        'control': 'CIS-OS-5',
                        'title': 'Security Group Missing/Short Description',
                        'severity': 'LOW',
                        'resource_type': 'security_group',
                        'resource_id': sg.id,
                        'security_group_name': sg.name,
                        'description': f'Security group "{sg.name}" has inadequate description',
                        'remediation': 'Add descriptive text (min 10 chars) explaining the purpose',
                        'evidence': {
                            'sg_id': sg.id,
                            'sg_name': sg.name,
                            'description': sg.description or '',
                            'description_length': len(sg.description) if sg.description else 0
                        },
                        'timestamp': self.scan_time
                    })

                    print(f"   ⚠️  LOW: SG '{sg.name}' has short/missing description")

            print(f"   ✅ CIS-OS-5 check completed\n")

        except Exception as e:
            print(f"   ⚠️  Error checking CIS-OS-5: {e}\n")

    def generate_report(self) -> Dict[str, Any]:
        """
        Tạo compliance report

        Returns:
            Dictionary chứa report data
        """
        # Đếm violations theo severity
        severity_counts = {
            'CRITICAL': 0,
            'HIGH': 0,
            'MEDIUM': 0,
            'LOW': 0
        }

        for v in self.violations:
            severity_counts[v['severity']] += 1

        # Calculate compliance score
        total_checks = 5  # 5 CIS controls
        failed_controls = len(set(v['control'] for v in self.violations))
        compliance_score = ((total_checks - failed_controls) / total_checks) * 100

        report = {
            'scan_time': self.scan_time,
            'compliance_score': round(compliance_score, 2),
            'total_violations': len(self.violations),
            'severity_counts': severity_counts,
            'violations': self.violations,
            'summary': {
                'total_checks': total_checks,
                'passed_checks': total_checks - failed_controls,
                'failed_checks': failed_controls
            }
        }

        return report

    def save_report(self, filename: str = 'scan_results.json'):
        """
        Lưu report ra file JSON

        Args:
            filename: Tên file output
        """
        report = self.generate_report()

        output_path = os.path.join(os.path.dirname(__file__), '..', filename)

        with open(output_path, 'w') as f:
            json.dump(report, f, indent=2)

        print(f"💾 Report saved to: {output_path}")

        return report


def main():
    """Main function"""

    # Kiểm tra cloud name từ args hoặc dùng default
    cloud_name = sys.argv[1] if len(sys.argv) > 1 else 'openstack'

    # Create scanner
    scanner = ComplianceScanner(cloud_name=cloud_name)

    # Run scan
    report = scanner.scan_all()

    # Save report
    scanner.save_report()

    # Print summary
    print("\n" + "="*60)
    print("📊 COMPLIANCE SCAN SUMMARY")
    print("="*60)
    print(f"Compliance Score: {report['compliance_score']}%")
    print(f"Total Violations: {report['total_violations']}")
    print(f"\nSeverity Breakdown:")
    for severity, count in report['severity_counts'].items():
        if count > 0:
            emoji = {'CRITICAL': '🔴', 'HIGH': '🟠', 'MEDIUM': '🟡', 'LOW': '🔵'}
            print(f"  {emoji[severity]} {severity}: {count}")

    print(f"\nChecks Summary:")
    print(f"  ✅ Passed: {report['summary']['passed_checks']}/{report['summary']['total_checks']}")
    print(f"  ❌ Failed: {report['summary']['failed_checks']}/{report['summary']['total_checks']}")

    print("\n" + "="*60 + "\n")

    # Exit with error code if violations found
    sys.exit(1 if report['total_violations'] > 0 else 0)


if __name__ == '__main__':
    main()
