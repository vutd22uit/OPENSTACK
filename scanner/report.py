#!/usr/bin/env python3
"""
Compliance Report Generator
Tạo báo cáo compliance từ scan results
"""

import json
import os
import sys
from datetime import datetime
from typing import Dict, Any, List


class ComplianceReporter:
    """Generator để tạo compliance reports"""

    def __init__(self, scan_results_file: str = 'scan_results.json'):
        """
        Khởi tạo reporter

        Args:
            scan_results_file: Path tới file JSON chứa scan results
        """
        self.results_file = scan_results_file
        self.load_results()

    def load_results(self):
        """Load scan results từ file"""
        if not os.path.exists(self.results_file):
            print(f"❌ Error: Scan results file not found: {self.results_file}")
            sys.exit(1)

        with open(self.results_file, 'r') as f:
            self.data = json.load(f)

        print(f"✅ Loaded scan results from: {self.results_file}")

    def generate_markdown_report(self) -> str:
        """
        Tạo báo cáo dạng Markdown

        Returns:
            String chứa Markdown content
        """
        md = []

        # Header
        md.append("# 🔒 OpenStack Compliance Report")
        md.append("")
        md.append(f"**Scan Time:** {self.data['scan_time']}")
        md.append(f"**Compliance Score:** {self.data['compliance_score']}%")
        md.append("")

        # Executive Summary
        md.append("## 📊 Executive Summary")
        md.append("")
        md.append(f"- **Total Violations:** {self.data['total_violations']}")
        md.append(f"- **Checks Passed:** {self.data['summary']['passed_checks']}/{self.data['summary']['total_checks']}")
        md.append(f"- **Checks Failed:** {self.data['summary']['failed_checks']}/{self.data['summary']['total_checks']}")
        md.append("")

        # Severity Breakdown
        md.append("## 🎯 Severity Breakdown")
        md.append("")
        md.append("| Severity | Count |")
        md.append("|----------|-------|")

        for severity in ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW']:
            count = self.data['severity_counts'][severity]
            emoji = {'CRITICAL': '🔴', 'HIGH': '🟠', 'MEDIUM': '🟡', 'LOW': '🔵'}
            md.append(f"| {emoji[severity]} {severity} | {count} |")

        md.append("")

        # Violations Detail
        if self.data['violations']:
            md.append("## ⚠️ Violations Detail")
            md.append("")

            # Group by control
            by_control = {}
            for v in self.data['violations']:
                control = v['control']
                if control not in by_control:
                    by_control[control] = []
                by_control[control].append(v)

            for control in sorted(by_control.keys()):
                violations = by_control[control]
                md.append(f"### {control}: {violations[0]['title']}")
                md.append("")
                md.append(f"**Severity:** {violations[0]['severity']}")
                md.append("")

                for i, v in enumerate(violations, 1):
                    md.append(f"#### Violation {i}")
                    md.append("")
                    md.append(f"- **Resource Type:** {v['resource_type']}")
                    md.append(f"- **Resource ID:** `{v['resource_id']}`")

                    if 'security_group_name' in v:
                        md.append(f"- **Security Group:** {v['security_group_name']}")

                    if 'resource_name' in v:
                        md.append(f"- **Resource Name:** {v['resource_name']}")

                    md.append(f"- **Description:** {v['description']}")
                    md.append(f"- **Remediation:** {v['remediation']}")
                    md.append("")

                    # Evidence
                    md.append("**Evidence:**")
                    md.append("```json")
                    md.append(json.dumps(v['evidence'], indent=2))
                    md.append("```")
                    md.append("")

        else:
            md.append("## ✅ No Violations Found")
            md.append("")
            md.append("All compliance checks passed!")
            md.append("")

        # Recommendations
        md.append("## 💡 Recommendations")
        md.append("")

        if self.data['severity_counts']['CRITICAL'] > 0:
            md.append("### 🔴 Critical Priority")
            md.append("- Address all CRITICAL violations immediately")
            md.append("- These represent immediate security risks")
            md.append("")

        if self.data['severity_counts']['HIGH'] > 0:
            md.append("### 🟠 High Priority")
            md.append("- Fix HIGH severity violations within 24 hours")
            md.append("- These could lead to security breaches")
            md.append("")

        if self.data['severity_counts']['MEDIUM'] > 0:
            md.append("### 🟡 Medium Priority")
            md.append("- Address MEDIUM violations within 1 week")
            md.append("- Review and minimize public exposure")
            md.append("")

        if self.data['severity_counts']['LOW'] > 0:
            md.append("### 🔵 Low Priority")
            md.append("- Fix LOW violations during next maintenance window")
            md.append("- Improve documentation and metadata")
            md.append("")

        # Footer
        md.append("---")
        md.append(f"*Generated by OpenStack Compliance Scanner v1.0*")
        md.append("")

        return "\n".join(md)

    def generate_html_report(self) -> str:
        """
        Tạo báo cáo dạng HTML

        Returns:
            String chứa HTML content
        """
        # Đơn giản, convert từ markdown
        md_content = self.generate_markdown_report()

        html = f"""<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>OpenStack Compliance Report</title>
    <style>
        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            line-height: 1.6;
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
            background: #f5f5f5;
        }}
        .container {{
            background: white;
            padding: 30px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }}
        h1 {{ color: #2c3e50; border-bottom: 3px solid #3498db; padding-bottom: 10px; }}
        h2 {{ color: #34495e; margin-top: 30px; border-bottom: 2px solid #ecf0f1; padding-bottom: 8px; }}
        h3 {{ color: #7f8c8d; }}
        .score {{
            font-size: 48px;
            font-weight: bold;
            text-align: center;
            margin: 20px 0;
            color: {self.get_score_color()};
        }}
        .summary {{
            display: flex;
            justify-content: space-around;
            margin: 30px 0;
        }}
        .summary-item {{
            text-align: center;
            padding: 20px;
            background: #ecf0f1;
            border-radius: 8px;
            flex: 1;
            margin: 0 10px;
        }}
        .summary-item .number {{
            font-size: 36px;
            font-weight: bold;
            color: #2c3e50;
        }}
        .summary-item .label {{
            color: #7f8c8d;
            margin-top: 5px;
        }}
        table {{
            width: 100%;
            border-collapse: collapse;
            margin: 20px 0;
        }}
        th, td {{
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid #ecf0f1;
        }}
        th {{
            background: #34495e;
            color: white;
        }}
        .violation {{
            background: #fff3cd;
            border-left: 4px solid #ffc107;
            padding: 15px;
            margin: 15px 0;
            border-radius: 4px;
        }}
        .violation.CRITICAL {{
            background: #f8d7da;
            border-left-color: #dc3545;
        }}
        .violation.HIGH {{
            background: #fff3cd;
            border-left-color: #fd7e14;
        }}
        .violation.MEDIUM {{
            background: #fff3cd;
            border-left-color: #ffc107;
        }}
        .violation.LOW {{
            background: #d1ecf1;
            border-left-color: #17a2b8;
        }}
        code {{
            background: #f8f9fa;
            padding: 2px 6px;
            border-radius: 3px;
            font-family: 'Courier New', monospace;
        }}
        pre {{
            background: #2c3e50;
            color: #ecf0f1;
            padding: 15px;
            border-radius: 5px;
            overflow-x: auto;
        }}
    </style>
</head>
<body>
    <div class="container">
        <h1>🔒 OpenStack Compliance Report</h1>
        <p><strong>Scan Time:</strong> {self.data['scan_time']}</p>

        <div class="score">{self.data['compliance_score']}%</div>

        <div class="summary">
            <div class="summary-item">
                <div class="number">{self.data['total_violations']}</div>
                <div class="label">Total Violations</div>
            </div>
            <div class="summary-item">
                <div class="number">{self.data['summary']['passed_checks']}</div>
                <div class="label">Checks Passed</div>
            </div>
            <div class="summary-item">
                <div class="number">{self.data['summary']['failed_checks']}</div>
                <div class="label">Checks Failed</div>
            </div>
        </div>

        <h2>🎯 Severity Breakdown</h2>
        <table>
            <tr>
                <th>Severity</th>
                <th>Count</th>
            </tr>
            <tr>
                <td>🔴 CRITICAL</td>
                <td>{self.data['severity_counts']['CRITICAL']}</td>
            </tr>
            <tr>
                <td>🟠 HIGH</td>
                <td>{self.data['severity_counts']['HIGH']}</td>
            </tr>
            <tr>
                <td>🟡 MEDIUM</td>
                <td>{self.data['severity_counts']['MEDIUM']}</td>
            </tr>
            <tr>
                <td>🔵 LOW</td>
                <td>{self.data['severity_counts']['LOW']}</td>
            </tr>
        </table>

        <h2>⚠️ Violations Detail</h2>
        {self.generate_violations_html()}

        <hr>
        <p><em>Generated by OpenStack Compliance Scanner v1.0</em></p>
    </div>
</body>
</html>
"""
        return html

    def generate_violations_html(self) -> str:
        """Generate HTML cho violations"""
        if not self.data['violations']:
            return "<p>✅ No violations found! All compliance checks passed.</p>"

        html_parts = []

        # Group by control
        by_control = {}
        for v in self.data['violations']:
            control = v['control']
            if control not in by_control:
                by_control[control] = []
            by_control[control].append(v)

        for control in sorted(by_control.keys()):
            violations = by_control[control]

            html_parts.append(f"<h3>{control}: {violations[0]['title']}</h3>")
            html_parts.append(f"<p><strong>Severity:</strong> {violations[0]['severity']}</p>")

            for i, v in enumerate(violations, 1):
                html_parts.append(f'<div class="violation {v["severity"]}">')
                html_parts.append(f"<h4>Violation {i}</h4>")
                html_parts.append(f"<p><strong>Resource:</strong> {v['resource_type']} - <code>{v['resource_id']}</code></p>")
                html_parts.append(f"<p><strong>Description:</strong> {v['description']}</p>")
                html_parts.append(f"<p><strong>Remediation:</strong> {v['remediation']}</p>")
                html_parts.append(f"<pre>{json.dumps(v['evidence'], indent=2)}</pre>")
                html_parts.append("</div>")

        return "\n".join(html_parts)

    def get_score_color(self) -> str:
        """Lấy màu dựa trên compliance score"""
        score = self.data['compliance_score']
        if score >= 90:
            return "#27ae60"  # Green
        elif score >= 70:
            return "#f39c12"  # Orange
        else:
            return "#e74c3c"  # Red

    def save_markdown_report(self, filename: str = 'compliance_report.md'):
        """Lưu Markdown report"""
        content = self.generate_markdown_report()

        with open(filename, 'w') as f:
            f.write(content)

        print(f"✅ Markdown report saved: {filename}")

    def save_html_report(self, filename: str = 'compliance_report.html'):
        """Lưu HTML report"""
        content = self.generate_html_report()

        with open(filename, 'w') as f:
            f.write(content)

        print(f"✅ HTML report saved: {filename}")


def main():
    """Main function"""

    # Parse arguments
    scan_file = sys.argv[1] if len(sys.argv) > 1 else 'scan_results.json'

    # Create reporter
    reporter = ComplianceReporter(scan_results_file=scan_file)

    # Generate reports
    print("\n📄 Generating reports...")

    reporter.save_markdown_report('compliance_report.md')
    reporter.save_html_report('compliance_report.html')

    print("\n✅ Reports generated successfully!")
    print("   - compliance_report.md")
    print("   - compliance_report.html")


if __name__ == '__main__':
    main()
