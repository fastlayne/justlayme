// Simple server without database for testing UI changes
const express = require('express');
const path = require('path');

const app = express();

// Serve static files
app.use(express.static(__dirname));

// Serve index.html for all routes
app.get('*', (req, res) => {
    res.sendFile(path.join(__dirname, 'index.html'));
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`JustLayMe Simple Server running on port ${PORT}`);
    console.log('Serving updated UI with Google Sign-In and simplified email verification');
});