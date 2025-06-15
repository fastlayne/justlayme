#!/usr/bin/env node

/**
 * Update JustLayMe memory with prompt layer session
 */

const fs = require('fs').promises;
const path = require('path');

async function updateMemory() {
    try {
        const memoryFile = path.join(__dirname, 'project-memory.json');
        const memory = JSON.parse(await fs.readFile(memoryFile, 'utf8'));

        // Add new session for prompt layer development
        const newSession = {
            id: "session_2025_06_14_prompt_layer",
            timestamp: "2025-06-14T22:00:00Z",
            duration: "~1 hour",
            summary: "Implemented dynamic prompt layer system for character personalization",
            accomplishments: [
                "Created sophisticated PromptLayer class for dynamic system prompt generation",
                "Built character customization system with 8+ personalization options",
                "Added API endpoints for character customization and preview",
                "Integrated prompt layer with Ollama API for Solar 10.7B model",
                "Added conversation history persistence to database",
                "Created validation system for user customizations",
                "Built dynamic prompt merging of base personalities + user preferences",
                "Added character relationship types (companion, mentor, friend, etc.)",
                "Implemented speech style, tone, and quirk customization",
                "Added real-time prompt preview functionality"
            ],
            problems_solved: [
                "Fixed character API endpoint structure for customization",
                "Resolved dynamic prompt generation complexity",
                "Added proper error handling for invalid customizations",
                "Fixed user_id passing from frontend to backend",
                "Corrected database schema for character storage"
            ],
            next_steps: [
                "Install Ollama with Solar 10.7B Instruct model",
                "Build character customization UI interface",
                "Test personalized AI responses with real Solar model",
                "Add character creation wizard for premium users",
                "Implement conversation memory and context"
            ],
            files_created: [
                "prompt-layer.js (dynamic prompt generation system)",
                "update-memory.js (memory system updater)"
            ],
            files_modified: [
                "character-api.js (added prompt layer integration)",
                "index.html (added user_id passing to chat API)"
            ],
            technologies: [
                "Dynamic Prompt Engineering",
                "Ollama API Integration",
                "Character Personalization System",
                "Database-driven AI Customization"
            ]
        };

        memory.sessions.push(newSession);

        // Update project state
        memory.project_state.prompt_layer_system = {
            status: "completed",
            details: "Dynamic prompt generation with user customization",
            files_affected: ["prompt-layer.js", "character-api.js"],
            last_updated: "2025-06-14T22:00:00Z"
        };

        memory.project_state.character_customization = {
            status: "completed",
            details: "API endpoints for character personalization",
            files_affected: ["character-api.js", "prompt-layer.js"],
            last_updated: "2025-06-14T22:00:00Z"
        };

        memory.project_state.ollama_integration = {
            status: "in_progress",
            details: "Solar 10.7B model integration pending installation",
            files_affected: ["character-api.js"],
            last_updated: "2025-06-14T22:00:00Z"
        };

        // Update todos
        memory.todos = [
            {
                id: "todo_ollama_install",
                task: "Install Ollama and Solar 10.7B Instruct model",
                priority: "high",
                category: "infrastructure",
                status: "pending",
                estimated_time: "20 minutes",
                dependencies: [],
                created_at: "2025-06-14T22:00:00Z"
            },
            {
                id: "todo_customization_ui",
                task: "Build character customization UI interface",
                priority: "high", 
                category: "frontend",
                status: "pending",
                estimated_time: "2 hours",
                dependencies: ["todo_ollama_install"],
                created_at: "2025-06-14T22:00:00Z"
            },
            {
                id: "todo_test_personalized_ai",
                task: "Test personalized AI responses with Solar model",
                priority: "high",
                category: "testing",
                status: "pending", 
                estimated_time: "1 hour",
                dependencies: ["todo_ollama_install", "todo_customization_ui"],
                created_at: "2025-06-14T22:00:00Z"
            }
        ];

        // Update knowledge graph
        memory.knowledge_graph.entities.prompt_layer = {
            type: "system",
            status: "implemented",
            capabilities: ["dynamic_prompts", "character_customization", "personality_merging"]
        };

        memory.knowledge_graph.entities.ollama = {
            type: "ai_service",
            status: "pending_install",
            model: "solar:10.7b-instruct-v1-q8_0",
            port: 11434
        };

        memory.knowledge_graph.relationships["character-api.js -> prompt_layer"] = "uses";
        memory.knowledge_graph.relationships["prompt_layer -> ollama"] = "generates_prompts_for";

        memory.last_updated = "2025-06-14T22:00:00Z";

        await fs.writeFile(memoryFile, JSON.stringify(memory, null, 2));
        console.log('✅ Updated JustLayMe memory with prompt layer session');
        console.log(`📊 Total sessions: ${memory.sessions.length}`);
        console.log(`📋 Total todos: ${memory.todos.length}`);
        console.log(`🏗️ Project features: ${Object.keys(memory.project_state).length}`);
        
    } catch (error) {
        console.error('❌ Failed to update memory:', error);
    }
}

updateMemory();