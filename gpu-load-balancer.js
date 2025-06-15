// GPU Load Balancer for JustLayMe
// Distributes AI model requests across multiple GPU servers

const express = require('express');
const httpProxy = require('http-proxy-middleware');
const axios = require('axios');

// GPU Server Configuration
const GPU_SERVERS = [
    {
        id: 'gpu-local',
        url: 'http://localhost:1234',  // Your local RTX 4060
        capacity: 60,
        currentLoad: 0,
        healthy: true,
        gpuType: 'RTX 4060',
        vram: '8GB'
    },
    {
        id: 'gpu-4090-1',
        url: 'http://YOUR_4090_SERVER_IP:1234',  // REPLACE WITH YOUR 4090 SERVER IP
        capacity: 100,
        currentLoad: 0,
        healthy: true,
        gpuType: 'RTX 4090',
        vram: '24GB'
    }
];

// Load balancing algorithm: Least Connection with GPU capacity weighting
function selectGPUServer() {
    const healthyServers = GPU_SERVERS.filter(server => server.healthy);
    
    if (healthyServers.length === 0) {
        throw new Error('No healthy GPU servers available');
    }

    // Calculate load factor for each server (lower is better)
    const serversWithLoadFactor = healthyServers.map(server => ({
        ...server,
        loadFactor: (server.currentLoad / server.capacity)
    }));

    // Sort by load factor and select the least loaded
    serversWithLoadFactor.sort((a, b) => a.loadFactor - b.loadFactor);
    return serversWithLoadFactor[0];
}

// Health check for GPU servers
async function healthCheck() {
    for (const server of GPU_SERVERS) {
        try {
            const response = await axios.get(`${server.url}/health`, { 
                timeout: 5000 
            });
            
            server.healthy = response.status === 200;
            
            // Update GPU metrics if available
            if (response.data) {
                server.currentLoad = response.data.activeRequests || 0;
                server.gpuUtilization = response.data.gpuUtilization || 0;
                server.vramUsage = response.data.vramUsage || 0;
            }
        } catch (error) {
            console.error(`Health check failed for ${server.id}:`, error.message);
            server.healthy = false;
        }
    }
}

// Run health checks every 10 seconds
setInterval(healthCheck, 10000);

// Create load balancer middleware
function createLoadBalancer() {
    return async (req, res, next) => {
        try {
            const server = selectGPUServer();
            
            // Increment load counter
            server.currentLoad++;
            
            // Create proxy to selected GPU server
            const proxy = httpProxy.createProxyMiddleware({
                target: server.url,
                changeOrigin: true,
                ws: true, // Enable WebSocket support
                onProxyReq: (proxyReq, req, res) => {
                    // Add custom headers
                    proxyReq.setHeader('X-GPU-Server', server.id);
                    proxyReq.setHeader('X-Request-ID', req.id);
                },
                onProxyRes: (proxyRes, req, res) => {
                    // Decrement load counter when response is complete
                    proxyRes.on('end', () => {
                        server.currentLoad = Math.max(0, server.currentLoad - 1);
                    });
                },
                onError: (err, req, res) => {
                    console.error(`Proxy error for ${server.id}:`, err);
                    server.currentLoad = Math.max(0, server.currentLoad - 1);
                    
                    // Mark server as unhealthy if too many errors
                    server.errorCount = (server.errorCount || 0) + 1;
                    if (server.errorCount > 5) {
                        server.healthy = false;
                    }
                    
                    // Try another server
                    next();
                }
            });
            
            proxy(req, res, next);
        } catch (error) {
            res.status(503).json({
                error: 'Service temporarily unavailable',
                message: 'All GPU servers are currently busy or offline'
            });
        }
    };
}

// Monitoring endpoint
function createMonitoringEndpoint(app) {
    app.get('/gpu-status', (req, res) => {
        const status = {
            servers: GPU_SERVERS.map(server => ({
                id: server.id,
                healthy: server.healthy,
                currentLoad: server.currentLoad,
                capacity: server.capacity,
                loadPercentage: Math.round((server.currentLoad / server.capacity) * 100),
                gpuType: server.gpuType,
                vram: server.vram,
                gpuUtilization: server.gpuUtilization,
                vramUsage: server.vramUsage
            })),
            totalCapacity: GPU_SERVERS.reduce((sum, s) => sum + s.capacity, 0),
            totalLoad: GPU_SERVERS.reduce((sum, s) => sum + s.currentLoad, 0),
            healthyServers: GPU_SERVERS.filter(s => s.healthy).length,
            totalServers: GPU_SERVERS.length
        };
        
        res.json(status);
    });
}

// WebSocket load balancing for streaming responses
function createWebSocketBalancer(server) {
    const WebSocket = require('ws');
    const wss = new WebSocket.Server({ server });
    
    wss.on('connection', (ws, req) => {
        try {
            const gpuServer = selectGPUServer();
            const targetUrl = gpuServer.url.replace('http', 'ws') + req.url;
            
            // Create connection to GPU server
            const gpuWs = new WebSocket(targetUrl);
            
            // Relay messages
            ws.on('message', (message) => {
                if (gpuWs.readyState === WebSocket.OPEN) {
                    gpuWs.send(message);
                }
            });
            
            gpuWs.on('message', (message) => {
                if (ws.readyState === WebSocket.OPEN) {
                    ws.send(message);
                }
            });
            
            // Handle disconnections
            ws.on('close', () => gpuWs.close());
            gpuWs.on('close', () => ws.close());
            
            // Handle errors
            ws.on('error', (err) => console.error('Client WS error:', err));
            gpuWs.on('error', (err) => console.error('GPU WS error:', err));
            
        } catch (error) {
            ws.send(JSON.stringify({ error: 'No GPU servers available' }));
            ws.close();
        }
    });
}

// Docker Compose configuration for GPU servers
const dockerComposeConfig = `
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
    command: -m /models/your-model.gguf -c 4096 --host 0.0.0.0 --port 1234
    ports:
      - "8081:1234"
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]

  gpu-server-2:
    image: ghcr.io/ggerganov/llama.cpp:server-cuda
    runtime: nvidia
    environment:
      - NVIDIA_VISIBLE_DEVICES=1
      - CUDA_VISIBLE_DEVICES=1
    volumes:
      - ./models:/models
    command: -m /models/your-model.gguf -c 4096 --host 0.0.0.0 --port 1234
    ports:
      - "8082:1234"
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]

  load-balancer:
    build: .
    ports:
      - "80:3000"
    environment:
      - GPU_SERVERS=gpu-server-1:1234,gpu-server-2:1234
    depends_on:
      - gpu-server-1
      - gpu-server-2
`;

// Kubernetes deployment for cloud GPU scaling
const k8sDeployment = `
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gpu-inference-server
spec:
  replicas: 3
  selector:
    matchLabels:
      app: gpu-inference
  template:
    metadata:
      labels:
        app: gpu-inference
    spec:
      containers:
      - name: llama-server
        image: ghcr.io/ggerganov/llama.cpp:server-cuda
        resources:
          limits:
            nvidia.com/gpu: 1
            memory: "32Gi"
            cpu: "8"
          requests:
            nvidia.com/gpu: 1
            memory: "24Gi"
            cpu: "4"
        volumeMounts:
        - name: models
          mountPath: /models
        ports:
        - containerPort: 1234
      volumes:
      - name: models
        persistentVolumeClaim:
          claimName: model-storage
---
apiVersion: v1
kind: Service
metadata:
  name: gpu-inference-service
spec:
  selector:
    app: gpu-inference
  ports:
  - port: 80
    targetPort: 1234
  type: LoadBalancer
`;

module.exports = {
    createLoadBalancer,
    createMonitoringEndpoint,
    createWebSocketBalancer,
    GPU_SERVERS,
    dockerComposeConfig,
    k8sDeployment
};