// Load Balancer Server for JustLayMe
const express = require('express');
const { createLoadBalancer, createMonitoringEndpoint, GPU_SERVERS } = require('./gpu-load-balancer');

const app = express();

// Add body parser for POST requests
app.use(express.json());

// Health check endpoint
app.get('/health', (req, res) => {
    res.json({ status: 'healthy', servers: GPU_SERVERS.length });
});

// GPU status monitoring
createMonitoringEndpoint(app);

// Load balancer for all API routes
app.use('/', createLoadBalancer());

const PORT = process.env.LOAD_BALANCER_PORT || 3000;
app.listen(PORT, () => {
    console.log(`GPU Load Balancer running on port ${PORT}`);
    console.log(`Monitor GPU status at http://localhost:${PORT}/gpu-status`);
});