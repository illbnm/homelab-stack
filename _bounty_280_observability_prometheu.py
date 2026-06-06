# Import necessary libraries
import time
import requests

# Set up the Prometheus metrics endpoint
url = "http://localhost:9090/api/v1/metrics"

# Set up the Grafana dashboard endpoint
url_dashboard = "http://localhost:8080/dashboard"

# Set up the Loki log endpoint
url_loki = "http://localhost:2886/api/v2/log"

# Set up the Tempo trace endpoint
url_tempo = "http://localhost:11800/tempo"

# Set up the Alertmanager endpoint
url_alertmanager = "http://localhost:8080/alertmanager"

# Set up the Uptime Kuma endpoint
url_uptime = "http://localhost:9280/api/v1/uptime"

# Define the metrics endpoint
def fetch_metrics():
    response = requests.get(url, timeout=30)
    if response.status_code == 200:
        return response.json()
        # Wait for a few seconds before trying again
        time.sleep(30)
        response = requests.get(url, timeout=30)
        if response.status_code == 200:
            return response.json()