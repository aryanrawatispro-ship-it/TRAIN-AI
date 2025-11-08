# Train-My-AI GPU Agent

## 7. BYO GPU Agent Specification

### Overview

The GPU Agent is a lightweight daemon that runs on user-provided GPU hardware, enabling the Train-My-AI platform to execute training jobs on BYO (Bring Your Own) GPU infrastructure.

### Features

- **Secure mTLS authentication** with the platform API
- **Heartbeat mechanism** for health monitoring
- **Job polling** for new training tasks
- **Docker container execution** with resource isolation
- **Real-time log streaming** back to the platform
- **GPU metrics reporting** (VRAM, utilization, temperature)
- **Graceful shutdown** (completes current job before exit)

### System Requirements

- **OS**: Linux (Ubuntu 20.04+ recommended)
- **GPU**: NVIDIA GPU with CUDA support
- **Docker**: 20.10+ with NVIDIA Container Toolkit
- **Go**: 1.21+ (for building from source)
- **Network**: Outbound HTTPS access to API

### Installation

#### 1. Install NVIDIA Container Toolkit

```bash
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/libnvidia-container/gpgkey | sudo apt-key add -
curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit
sudo systemctl restart docker
```

#### 2. Download Agent Binary

```bash
# Download latest release
wget https://github.com/train-my-ai/gpu-agent/releases/latest/download/gpu-agent-linux-amd64 -O gpu-agent
chmod +x gpu-agent

# Or build from source
git clone https://github.com/train-my-ai/gpu-agent.git
cd gpu-agent
go build -o gpu-agent main.go
```

#### 3. Register GPU Node

```bash
# Register via web UI at https://app.train-my-ai.com/gpu-nodes
# This will generate:
# - Node ID (e.g., node_abc123)
# - mTLS certificate (client.crt)
# - mTLS private key (client.key)

# Save certificates
mkdir -p certs
# Copy downloaded client.crt and client.key to ./certs/
```

#### 4. Run Agent

```bash
./gpu-agent \
  --node-id=node_abc123 \
  --name="My RTX 4090" \
  --api=https://api.train-my-ai.com \
  --cert=./certs/client.crt \
  --key=./certs/client.key
```

### Running as Systemd Service

```bash
# Create service file
sudo tee /etc/systemd/system/gpu-agent.service > /dev/null <<EOF
[Unit]
Description=Train-My-AI GPU Agent
After=network.target docker.service
Requires=docker.service

[Service]
Type=simple
User=gpuagent
WorkingDirectory=/opt/gpu-agent
ExecStart=/opt/gpu-agent/gpu-agent \
  --node-id=node_abc123 \
  --name="Production GPU" \
  --api=https://api.train-my-ai.com \
  --cert=/opt/gpu-agent/certs/client.crt \
  --key=/opt/gpu-agent/certs/client.key
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable gpu-agent
sudo systemctl start gpu-agent

# Check status
sudo systemctl status gpu-agent
sudo journalctl -u gpu-agent -f
```

### Configuration Options

| Flag | Default | Description |
|------|---------|-------------|
| `--node-id` | (required) | GPU node ID from registration |
| `--name` | "" | Human-readable node name |
| `--api` | `https://api.train-my-ai.com` | API base URL |
| `--cert` | `./certs/client.crt` | mTLS certificate path |
| `--key` | `./certs/client.key` | mTLS private key path |
| `--poll-interval` | `10s` | Job polling interval |
| `--heartbeat-interval` | `30s` | Heartbeat interval |

### Security Model

1. **Authentication**: Mutual TLS (mTLS) with client certificates
2. **Container Isolation**:
   - No network access (except S3, API via explicit allow)
   - Read-only filesystem
   - Resource limits (CPU, memory, GPU)
   - Non-root user
   - No new privileges
3. **Secrets**: Injected as environment variables (fetched from Vault by API)
4. **Audit**: All job executions logged to platform audit trail

### Monitoring

The agent exposes metrics via log output:

```
2025-11-08T14:30:00+05:30 INFO  Heartbeat sent: ONLINE | VRAM: 22,000 MB free
2025-11-08T14:30:30+05:30 INFO  Received job: job_xyz789 (image: trainmyai/sft-worker:v1.0.0)
2025-11-08T14:30:45+05:30 INFO  Job job_xyz789 status updated: RUNNING
2025-11-08T15:00:12+05:30 INFO  Job job_xyz789 completed successfully
```

Platform dashboard shows:
- Node status (ONLINE/OFFLINE/BUSY/ERROR)
- GPU utilization and VRAM usage
- Temperature
- Jobs executed (count, success rate)
- Uptime

### Troubleshooting

#### Agent won't start

```bash
# Check Docker is running
sudo systemctl status docker

# Check NVIDIA runtime
docker run --rm --gpus all nvidia/cuda:12.1.0-base-ubuntu22.04 nvidia-smi

# Check certificates
openssl x509 -in certs/client.crt -text -noout
```

#### Jobs failing immediately

```bash
# Check Docker logs
docker logs $(docker ps -a -q --filter ancestor=trainmyai/sft-worker:v1.0.0 --latest)

# Check VRAM available
nvidia-smi

# Check disk space
df -h
```

#### Heartbeat failures

```bash
# Check network connectivity
curl -v https://api.train-my-ai.com/health

# Check certificate validity
openssl s_client -connect api.train-my-ai.com:443 \
  -cert certs/client.crt -key certs/client.key
```

### Uninstall

```bash
# Stop and disable service
sudo systemctl stop gpu-agent
sudo systemctl disable gpu-agent
sudo rm /etc/systemd/system/gpu-agent.service

# Remove files
sudo rm -rf /opt/gpu-agent

# Deregister node via web UI
```

### License

MIT License
