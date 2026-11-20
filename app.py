import os

from flask import Flask

app = Flask(__name__)


@app.route('/')
def home():
    return "Hello, DevOps World! V1"


if __name__ == '__main__':
    # Cloud hosts (Render, etc.) inject the port via the PORT environment
    # variable. Fall back to 5000 for local runs, Docker and Kubernetes.
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port)
