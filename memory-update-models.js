#!/usr/bin/env node

// Update memory with new model imports and character mapping

const fs = require('fs').promises;
const path = require('path');

async function updateMemory() {
    const memoryFile = path.join(__dirname, 'project-memory.json');
    
    try {
        const data = await fs.readFile(memoryFile, 'utf8');
        const memory = JSON.parse(data);
        
        // Add new session for model imports and character mapping
        const newSession = {
            "id": "session_2025_06_16_model_imports",
            "timestamp": "2025-06-16T02:15:00Z",
            "duration": "~2 hours",
            "summary": "Successfully imported Mythomax and Dolphin models, updated character-to-model mapping",
            "accomplishments": [
                "Found downloaded models in /home/fastl/mythomax and /home/fastl/dolphin directories",
                "Created Ollama Modelfiles for both Mythomax-13B and Dolphin-Mixtral models",
                "Successfully imported mythomax-13b:latest (7.9GB) into Ollama",
                "Successfully imported dolphin-mixtral:latest (26GB) into Ollama", 
                "Updated model-manager.js with correct model names and character mapping",
                "Fixed model discovery to detect all 3 available models",
                "Established character-specific model assignments for better personality matching",
                "Updated character selector UI positioning to not cover navigation",
                "Fixed email verification route handling completely",
                "Configured Proton Bridge email system with proper credentials",
                "Successfully tested email verification end-to-end flow"
            ],
            "problems_solved": [
                "Fixed character selector covering JustLayMe title bar and navigation",
                "Resolved model discovery only finding Zephyr instead of all models",
                "Updated model preference order to prioritize larger, more capable models",
                "Fixed character-to-model mapping to use actual imported model names",
                "Corrected email verification 'Cannot GET /verify-email' error",
                "Configured Proton Bridge SMTP with correct host (192.168.0.95:1025)",
                "Added TLS certificate handling for Proton Bridge self-signed certs"
            ],
            "technical_implementations": [
                "Model import process using custom Ollama Modelfiles",
                "Updated ModelManager.selectBestModel() with new model names",
                "Character-specific model mapping for personality optimization",
                "Fixed character selector CSS positioning (top: 64px instead of top: 0)",
                "Added /verify-email route to serve frontend for email verification",
                "SMTP configuration with rejectUnauthorized: false for Proton Bridge"
            ],
            "files_created": [
                "/home/fastl/mythomax/Modelfile (Ollama model configuration)",
                "/home/fastl/dolphin/Modelfile (Ollama model configuration)", 
                "memory-update-models.js (this memory updater)"
            ],
            "files_modified": [
                "model-manager.js (updated model mapping and discovery)",
                "character-api.js (added /verify-email route, fixed SMTP config)",
                "index.html (fixed character selector positioning)",
                "premium-style.css (adjusted chat container margins)"
            ],
            "technologies": [
                "Ollama Model Management",
                "GGUF Model Format", 
                "Mythomax-L2-13B AI Model",
                "Dolphin-2.7-Mixtral-8x7B AI Model",
                "Multi-Model Character Assignment",
                "Proton Bridge SMTP Integration"
            ]
        };
        
        memory.sessions.push(newSession);
        
        // Update project state
        memory.project_state.multi_model_system = {
            "status": "completed",
            "details": "3 models active - Mythomax-13B, Dolphin-Mixtral, Zephyr-7B with character-specific assignments",
            "files_affected": [
                "model-manager.js"
            ],
            "last_updated": "2025-06-16T02:15:00Z"
        };
        
        memory.project_state.email_verification_system = {
            "status": "completed", 
            "details": "Full end-to-end email verification working with Proton Bridge integration",
            "files_affected": [
                "character-api.js",
                "index.html"
            ],
            "last_updated": "2025-06-16T02:15:00Z"
        };
        
        memory.project_state.character_ui_optimization = {
            "status": "completed",
            "details": "Character selector repositioned to thin bar below navigation, doesn't block chat input",
            "files_affected": [
                "index.html", 
                "premium-style.css"
            ],
            "last_updated": "2025-06-16T02:15:00Z"
        };
        
        // Update knowledge graph with new models
        memory.knowledge_graph.entities.mythomax_model = {
            "type": "ai_model",
            "status": "active",
            "model": "mythomax-13b:latest", 
            "size": "7.9GB",
            "parameters": "13B",
            "capabilities": [
                "uncensored",
                "creative",
                "reasoning",
                "detailed_responses"
            ]
        };
        
        memory.knowledge_graph.entities.dolphin_model = {
            "type": "ai_model", 
            "status": "active",
            "model": "dolphin-mixtral:latest",
            "size": "26GB", 
            "parameters": "46.7B",
            "capabilities": [
                "uncensored",
                "roleplay", 
                "creative",
                "expert_knowledge"
            ]
        };
        
        memory.knowledge_graph.entities.character_model_mapping = {
            "type": "system",
            "status": "implemented",
            "mappings": {
                "uncensored_gpt": "mythomax-13b:latest",
                "roleplay": "dolphin-mixtral:latest", 
                "companion": "mythomax-13b:latest",
                "dominant": "mythomax-13b:latest",
                "submissive": "zephyr:7b-alpha-q4_0"
            }
        };
        
        // Add relationships
        memory.knowledge_graph.relationships["character_model_mapping -> mythomax_model"] = "uses";
        memory.knowledge_graph.relationships["character_model_mapping -> dolphin_model"] = "uses";
        memory.knowledge_graph.relationships["character_model_mapping -> zephyr_model"] = "uses";
        memory.knowledge_graph.relationships["model_manager -> character_model_mapping"] = "implements";
        
        // Update last modified
        memory.last_updated = "2025-06-16T02:15:00Z";
        
        await fs.writeFile(memoryFile, JSON.stringify(memory, null, 2));
        console.log('✅ Memory updated successfully with model imports and character mapping!');
        
    } catch (error) {
        console.error('❌ Error updating memory:', error);
    }
}

updateMemory();