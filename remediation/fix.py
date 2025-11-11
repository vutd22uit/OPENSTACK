#!/usr/bin/env python3
"""
Auto-Remediation Module
Tự động sửa các vi phạm compliance trên OpenStack
"""

import os
import sys
import json
from datetime import datetime
from typing import Dict, Any, List

try:
    from openstack import connect
    from openstack.exceptions import OpenStackCloudException
except ImportError:
    print("❌ Error: openstacksdk not installed. Run: pip install openstacksdk")
    sys.exit(1)


class ComplianceRemediator:
    """Module để tự động sửa compliance violations"""

    def __init__(self, cloud_name: str = 'openstack', dry_run: bool = False):
        """
        Khởi tạo remediator

        Args:
            cloud_name: Tên cloud trong clouds.yaml
            dry_run: Nếu True, chỉ show actions mà không execute
        """
        try:
            self.conn = connect(cloud=cloud_name)
            print(f"✅ Connected to OpenStack: {cloud_name}")
        except Exception as e:
            print(f"❌ Failed to connect to OpenStack: {e}")
            sys.exit(1)

        self.dry_run = dry_run
        self.remediation_log = []

        if dry_run:
            print("⚠️  DRY RUN MODE: No changes will be made\n")

    def load_scan_results(self, filename: str = 'scan_results.json') -> Dict[str, Any]:
        """
        Load scan results từ file

        Args:
            filename: Tên file chứa scan results

        Returns:
            Dictionary chứa scan results
        """
        if not os.path.exists(filename):
            print(f"❌ Error: Scan results file not found: {filename}")
            sys.exit(1)

        with open(filename, 'r') as f:
            data = json.load(f)

        print(f"✅ Loaded scan results from: {filename}")
        print(f"   Found {len(data['violations'])} violation(s)\n")

        return data

    def remediate_all(self, scan_results: Dict[str, Any]):
        """
        Tự động sửa tất cả violations có thể

        Args:
            scan_results: Dictionary chứa scan results
        """
        print("="*60)
        print("🔧 Starting Auto-Remediation")
        print("="*60 + "\n")

        violations = scan_results['violations']

        for violation in violations:
            control = violation['control']

            # Route tới remediation function tương ứng
            if control == 'CIS-OS-1':
                self.fix_cis_os_1(violation)
            elif control == 'CIS-OS-2':
                self.fix_cis_os_2(violation)
            elif control == 'CIS-OS-3':
                self.fix_cis_os_3(violation)
            elif control == 'CIS-OS-4':
                self.fix_cis_os_4(violation)
            elif control == 'CIS-OS-5':
                self.fix_cis_os_5(violation)

        # Save remediation log
        self.save_remediation_log()

        # Print summary
        self.print_summary()

    def fix_cis_os_1(self, violation: Dict[str, Any]):
        """
        Fix CIS-OS-1: Xóa SSH rule open to world

        Args:
            violation: Violation data
        """
        print(f"🔧 [CIS-OS-1] Fixing SSH open to world...")

        rule_id = violation['evidence']['rule_id']
        sg_name = violation.get('security_group_name', 'unknown')

        try:
            if not self.dry_run:
                # Xóa security group rule nguy hiểm
                self.conn.network.delete_security_group_rule(rule_id)

            print(f"   ✅ Deleted dangerous SSH rule {rule_id} from SG '{sg_name}'")

            self.log_remediation({
                'control': 'CIS-OS-1',
                'action': 'deleted_security_group_rule',
                'resource_id': rule_id,
                'security_group': sg_name,
                'status': 'success',
                'dry_run': self.dry_run,
                'timestamp': datetime.now().isoformat()
            })

        except Exception as e:
            print(f"   ❌ Failed to delete rule {rule_id}: {e}")

            self.log_remediation({
                'control': 'CIS-OS-1',
                'action': 'delete_security_group_rule_failed',
                'resource_id': rule_id,
                'status': 'failed',
                'error': str(e),
                'timestamp': datetime.now().isoformat()
            })

    def fix_cis_os_2(self, violation: Dict[str, Any]):
        """
        Fix CIS-OS-2: Xóa custom rules khỏi default security group

        Args:
            violation: Violation data
        """
        print(f"🔧 [CIS-OS-2] Fixing default security group rules...")

        rule_ids = violation['evidence'].get('rule_ids', [])

        for rule_id in rule_ids:
            try:
                if not self.dry_run:
                    self.conn.network.delete_security_group_rule(rule_id)

                print(f"   ✅ Deleted rule {rule_id} from default SG")

                self.log_remediation({
                    'control': 'CIS-OS-2',
                    'action': 'deleted_default_sg_rule',
                    'resource_id': rule_id,
                    'status': 'success',
                    'dry_run': self.dry_run,
                    'timestamp': datetime.now().isoformat()
                })

            except Exception as e:
                print(f"   ❌ Failed to delete rule {rule_id}: {e}")

                self.log_remediation({
                    'control': 'CIS-OS-2',
                    'action': 'delete_default_sg_rule_failed',
                    'resource_id': rule_id,
                    'status': 'failed',
                    'error': str(e),
                    'timestamp': datetime.now().isoformat()
                })

    def fix_cis_os_3(self, violation: Dict[str, Any]):
        """
        Fix CIS-OS-3: Volume encryption
        Note: Không thể encrypt volume đã tồn tại, chỉ log warning

        Args:
            violation: Violation data
        """
        print(f"⚠️  [CIS-OS-3] Volume encryption cannot be auto-fixed")

        volume_id = violation['resource_id']
        volume_name = violation.get('resource_name', 'unknown')

        print(f"   ⚠️  Volume '{volume_name}' ({volume_id}) must be recreated with encryption")
        print(f"   💡 Manual action required:")
        print(f"      1. Backup volume data")
        print(f"      2. Create new encrypted volume")
        print(f"      3. Restore data to new volume")
        print(f"      4. Delete old unencrypted volume")

        self.log_remediation({
            'control': 'CIS-OS-3',
            'action': 'manual_remediation_required',
            'resource_id': volume_id,
            'resource_name': volume_name,
            'status': 'manual_action_required',
            'notes': 'Volume encryption cannot be enabled on existing volumes',
            'timestamp': datetime.now().isoformat()
        })

    def fix_cis_os_4(self, violation: Dict[str, Any]):
        """
        Fix CIS-OS-4: Detach floating IPs (optional, cần confirm)
        Không tự động detach vì có thể break production

        Args:
            violation: Violation data
        """
        print(f"⚠️  [CIS-OS-4] Floating IP remediation requires manual review")

        floating_ip = violation['evidence']['floating_ip']
        fixed_ip = violation['evidence']['fixed_ip']

        print(f"   ⚠️  Floating IP {floating_ip} → {fixed_ip}")
        print(f"   💡 Manual action required:")
        print(f"      1. Verify if public access is necessary")
        print(f"      2. Consider using bastion host or VPN instead")
        print(f"      3. If not needed, detach floating IP:")
        print(f"         openstack floating ip unset {floating_ip}")

        self.log_remediation({
            'control': 'CIS-OS-4',
            'action': 'manual_review_required',
            'floating_ip': floating_ip,
            'fixed_ip': fixed_ip,
            'status': 'manual_review_required',
            'notes': 'Floating IP detachment requires business approval',
            'timestamp': datetime.now().isoformat()
        })

    def fix_cis_os_5(self, violation: Dict[str, Any]):
        """
        Fix CIS-OS-5: Add description to security group

        Args:
            violation: Violation data
        """
        print(f"🔧 [CIS-OS-5] Fixing security group description...")

        sg_id = violation['resource_id']
        sg_name = violation.get('security_group_name', 'unknown')

        # Generate một description mặc định
        new_description = f"Security group {sg_name} - auto-added description for compliance"

        try:
            if not self.dry_run:
                # Update security group với description
                self.conn.network.update_security_group(
                    sg_id,
                    description=new_description
                )

            print(f"   ✅ Added description to SG '{sg_name}'")

            self.log_remediation({
                'control': 'CIS-OS-5',
                'action': 'updated_security_group_description',
                'resource_id': sg_id,
                'security_group_name': sg_name,
                'new_description': new_description,
                'status': 'success',
                'dry_run': self.dry_run,
                'timestamp': datetime.now().isoformat()
            })

        except Exception as e:
            print(f"   ❌ Failed to update SG {sg_name}: {e}")

            self.log_remediation({
                'control': 'CIS-OS-5',
                'action': 'update_sg_description_failed',
                'resource_id': sg_id,
                'status': 'failed',
                'error': str(e),
                'timestamp': datetime.now().isoformat()
            })

    def log_remediation(self, log_entry: Dict[str, Any]):
        """
        Log remediation action

        Args:
            log_entry: Dictionary chứa log data
        """
        self.remediation_log.append(log_entry)

    def save_remediation_log(self, filename: str = 'remediation_log.json'):
        """
        Save remediation log ra file

        Args:
            filename: Tên file output
        """
        with open(filename, 'w') as f:
            json.dump({
                'timestamp': datetime.now().isoformat(),
                'dry_run': self.dry_run,
                'total_actions': len(self.remediation_log),
                'actions': self.remediation_log
            }, f, indent=2)

        print(f"\n💾 Remediation log saved: {filename}")

    def print_summary(self):
        """Print remediation summary"""
        print("\n" + "="*60)
        print("📊 REMEDIATION SUMMARY")
        print("="*60)

        success = len([x for x in self.remediation_log if x['status'] == 'success'])
        failed = len([x for x in self.remediation_log if x['status'] == 'failed'])
        manual = len([x for x in self.remediation_log if 'manual' in x['status']])

        print(f"Total Actions: {len(self.remediation_log)}")
        print(f"  ✅ Successful: {success}")
        print(f"  ❌ Failed: {failed}")
        print(f"  ⚠️  Manual Review Required: {manual}")

        if self.dry_run:
            print("\n⚠️  DRY RUN: No actual changes were made")

        print("="*60 + "\n")


def main():
    """Main function"""

    # Parse arguments
    dry_run = '--dry-run' in sys.argv
    cloud_name = 'openstack'

    # Extract cloud name if provided
    for arg in sys.argv:
        if arg.startswith('--cloud='):
            cloud_name = arg.split('=')[1]

    # Create remediator
    remediator = ComplianceRemediator(cloud_name=cloud_name, dry_run=dry_run)

    # Load scan results
    scan_results = remediator.load_scan_results('scan_results.json')

    if not scan_results['violations']:
        print("✅ No violations to remediate!")
        return

    # Ask for confirmation if not dry-run
    if not dry_run:
        print("⚠️  WARNING: This will make changes to your OpenStack environment!")
        print(f"   {len(scan_results['violations'])} violation(s) will be remediated.")
        response = input("\nContinue? (yes/no): ")

        if response.lower() != 'yes':
            print("❌ Remediation cancelled")
            return

    # Run remediation
    remediator.remediate_all(scan_results)


if __name__ == '__main__':
    main()
