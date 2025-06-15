#!/bin/bash

# Setup script for JustLayMe GPU servers
# This sets up multiple GPU servers for load balancing

echo "=== JustLayMe GPU Server Setup ==="
echo ""

# Function to check if running on system with NVIDIA GPU
check_gpu() {
    if ! command -v nvidia-smi &> /dev/null; then
        echo "ERROR: nvidia-smi not found. Please install NVIDIA drivers."
        exit 1
    fi
    
    echo "GPU Status:"
    nvidia-smi --query-gpu=name,memory.total,memory.free --format=csv
    echo ""
}

# Install Docker with GPU support
install_docker() {
    echo "Installing Docker with GPU support..."
    
    # Install Docker
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    
    # Install NVIDIA Container Toolkit
    distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
    curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
    curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list
    
    sudo apt-get update
    sudo apt-get install -y nvidia-container-toolkit
    sudo systemctl restart docker
    
    echo "Docker with GPU support installed!"
}

# Download AI models
download_models() {
    echo "Downloading AI models..."
    mkdir -p models
    
    # Download Llama 2 7B model (example)
    # You'll need to replace this with your actual model
    echo "Please download your preferred model and place it in the ./models directory"
    echo "Recommended models:"
    echo "- Llama 2 7B: https://huggingface.co/TheBloke/Llama-2-7B-Chat-GGUF"
    echo "- Mistral 7B: https://huggingface.co/TheBloke/Mistral-7B-Instruct-v0.1-GGUF"
}

# Create docker-compose.yml
create_docker_compose() {
    cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  gpu-server-1:
    image: ghcr.io/ggerganov/llama.cpp:server-cuda
    runtime: nvidia
    environment:
      - NVIDIA_VISIBLE_DEVICES=0
      - CUDA_VISIBLE_DEVICES=0
    volumes:
      - ./models:/models
    command: >
      -m /models/llama-2-7b-chat.Q4_K_M.gguf 
      -c 4096 
      --host 0.0.0.0 
      --port 1234
      -ngl 35
      --threads 8
    ports:
      - "8081:1234"
    restart: unless-stopped
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]

  nginx-load-balancer:
    image: nginx:alpine
    ports:
      - "1234:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
    depends_on:
      - gpu-server-1
    restart: unless-stopped
EOF

    # Create nginx.conf for load balancing
    cat > nginx.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    upstream gpu_servers {
        least_conn;
        server gpu-server-1:1234 weight=1 max_fails=3 fail_timeout=30s;
        # Add more servers as needed
    }

    server {
        listen 80;
        
        location / {
            proxy_pass http://gpu_servers;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            # Timeouts for long-running AI requests
            proxy_connect_timeout 60s;
            proxy_send_timeout 300s;
            proxy_read_timeout 300s;
        }
        
        location /health {
            access_log off;
            return 200 "healthy\n";
        }
    }
}
EOF
}

# Setup monitoring
setup_monitoring() {
    echo "Setting up GPU monitoring..."
    
    # Create monitoring script
    cat > monitor-gpu.sh << 'EOF'
#!/bin/bash
while true; do
    clear
    echo "=== GPU Server Status ==="
    echo "Time: $(date)"
    echo ""
    nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu --format=csv
    echo ""
    echo "Docker containers:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    sleep 5
done
EOF
    chmod +x monitor-gpu.sh
}

# Main setup flow
main() {
    echo "Starting GPU server setup..."
    
    # Check for GPU
    check_gpu
    
    # Install dependencies
    read -p "Install Docker with GPU support? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        install_docker
    fi
    
    # Download models
    download_models
    
    # Create configuration files
    create_docker_compose
    
    # Setup monitoring
    setup_monitoring
    
    echo ""
    echo "=== Setup Complete ==="
    echo ""
    echo "Next steps:"
    echo "1. Place your AI model in ./models/"
    echo "2. Update docker-compose.yml with your model filename"
    echo "3. Run: docker-compose up -d"
    echo "4. Monitor GPUs: ./monitor-gpu.sh"
    echo "5. Update character-api.js to use http://localhost:1234"
    echo ""
    echo "For multiple GPU servers:"
    echo "- Duplicate the gpu-server-1 service in docker-compose.yml"
    echo "- Change NVIDIA_VISIBLE_DEVICES to use different GPUs"
    echo "- Update nginx.conf upstream servers"
}

# Run main setup
main