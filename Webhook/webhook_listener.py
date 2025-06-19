from flask import Flask, request, jsonify
import subprocess
import instana

app = Flask(__name__)

ZABBIX_SERVER = "10.245.1.5"

def send_to_zabbix(alert_data):
    text = alert_data.get("issue", {}).get("text", "1")  # Extract severity
    severity = alert_data.get("issue", {}).get("severity", "")
    start_time = alert_data.get("issue", {}).get("start", "")  # Extract start time
    start_time_str = str(start_time)  # Convert start to string if it's not empty
    tags = alert_data.get("issue", {}).get("tags", "")
    host = tags if tags else "Instana Webhook Fallback"
    tags = alert_data.get("issue", {}).get("tags", "")
    host = tags if tags else "Instana Webhook Fallback"
    # Combine severity and start_time, ensure start_time is appended correctly
    value = f"{text} | {severity} | {start_time_str}"
    cmd = [
        "/usr/bin/zabbix_sender",
        "-z", ZABBIX_SERVER,
        "-s", host,
        "-k", "instana.alert",
        "-o", value,
        "-vv"  # Enable verbose output
    ]

    result = subprocess.run(cmd, capture_output=True, text=True)

    # Print output for debugging
    print("CMD:", " ".join(cmd))
    print("STDOUT:", result.stdout)
    print("STDERR:", result.stderr)

    return {
        "cmd": " ".join(cmd),
        "stdout": result.stdout.strip(),
        "stderr": result.stderr.strip()
    }

@app.route("/webhook", methods=["POST"])
def webhook():
    try:
        alert_data = request.json
        print("Received Instana alert:", alert_data)

        result = send_to_zabbix(alert_data)
        return jsonify({"status": "success", "data": result}), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 400

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
