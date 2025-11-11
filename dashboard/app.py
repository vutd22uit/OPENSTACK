#!/usr/bin/env python3
"""
Flask Dashboard cho OpenStack Compliance
Hiển thị compliance score và violations
"""

import os
import json
from datetime import datetime
from flask import Flask, render_template, jsonify

app = Flask(__name__)

# Path tới scan results
SCAN_RESULTS_FILE = os.path.join(os.path.dirname(__file__), '..', 'scan_results.json')


def load_scan_results():
    """Load scan results từ file"""
    if not os.path.exists(SCAN_RESULTS_FILE):
        return None

    try:
        with open(SCAN_RESULTS_FILE, 'r') as f:
            return json.load(f)
    except Exception as e:
        print(f"Error loading scan results: {e}")
        return None


def calculate_compliance_score(data):
    """Calculate compliance score từ scan data"""
    if not data:
        return 0

    return data.get('compliance_score', 0)


@app.route('/')
def index():
    """Main dashboard page"""
    data = load_scan_results()

    if not data:
        return render_template('dashboard.html',
                             error="No scan results available. Run scanner first: python scanner/scan.py")

    score = calculate_compliance_score(data)
    violations = data.get('violations', [])
    severity_counts = data.get('severity_counts', {})
    summary = data.get('summary', {})
    scan_time = data.get('scan_time', 'Unknown')

    # Format scan time
    try:
        scan_dt = datetime.fromisoformat(scan_time)
        scan_time_formatted = scan_dt.strftime("%Y-%m-%d %H:%M:%S")
    except:
        scan_time_formatted = scan_time

    # Group violations by control
    violations_by_control = {}
    for v in violations:
        control = v['control']
        if control not in violations_by_control:
            violations_by_control[control] = []
        violations_by_control[control].append(v)

    return render_template('dashboard.html',
                         score=score,
                         violations=violations,
                         violations_by_control=violations_by_control,
                         severity_counts=severity_counts,
                         summary=summary,
                         scan_time=scan_time_formatted,
                         total_violations=len(violations))


@app.route('/api/scan-results')
def api_scan_results():
    """API endpoint để lấy scan results"""
    data = load_scan_results()

    if not data:
        return jsonify({'error': 'No scan results available'}), 404

    return jsonify(data)


@app.route('/api/compliance-score')
def api_compliance_score():
    """API endpoint để lấy compliance score"""
    data = load_scan_results()

    if not data:
        return jsonify({'error': 'No scan results available'}), 404

    return jsonify({
        'score': data.get('compliance_score', 0),
        'scan_time': data.get('scan_time', 'Unknown')
    })


@app.route('/health')
def health():
    """Health check endpoint"""
    return jsonify({'status': 'healthy', 'timestamp': datetime.now().isoformat()})


if __name__ == '__main__':
    print("="*60)
    print("🚀 Starting OpenStack Compliance Dashboard")
    print("="*60)
    print("\n📊 Dashboard will be available at: http://localhost:5000")
    print("🔄 Auto-reload enabled (for development)")
    print("\n💡 Press Ctrl+C to stop\n")

    app.run(host='0.0.0.0', port=5000, debug=True)
