/**
 * Model Manager for JustLayMe
 * Handles multiple AI models and smart model selection
 */

class ModelManager {
    constructor() {
        this.models = [];
        this.defaultModel = null;
        this.modelCapabilities = {
            'solar:10.7b-instruct-v1-q8_0': {
                strengths: ['reasoning', 'uncensored', 'detailed_responses'],
                best_for: ['intellectual', 'creative'],
                memory_usage: 'high',
                speed: 'medium'
            },
            'zephyr:7b-alpha-q4_0': {
                strengths: ['fast', 'conversational', 'helpful'],
                best_for: ['playful', 'gamer', 'adventurous'], 
                memory_usage: 'medium',
                speed: 'fast'
            },
            'mistral:7b-instruct': {
                strengths: ['balanced', 'reliable', 'efficient'],
                best_for: ['general', 'professional'],
                memory_usage: 'medium',
                speed: 'fast'
            },
            'llama2:7b-chat': {
                strengths: ['safe', 'helpful', 'accurate'],
                best_for: ['general', 'educational'],
                memory_usage: 'medium',
                speed: 'medium'
            },
            'dolphin-mistral:7b': {
                strengths: ['uncensored', 'creative', 'roleplay'],
                best_for: ['creative', 'adventurous'],
                memory_usage: 'medium',
                speed: 'fast'
            },
            'neural-chat:7b': {
                strengths: ['conversation', 'empathy', 'natural'],
                best_for: ['emotional', 'supportive'],
                memory_usage: 'medium',
                speed: 'fast'
            }
        };
    }

    async discoverModels() {
        try {
            const response = await fetch('http://localhost:11434/api/tags');
            const data = await response.json();
            
            this.models = data.models.map(model => ({
                name: model.name,
                size: model.size,
                modified: model.modified_at,
                capabilities: this.modelCapabilities[model.name] || {
                    strengths: ['general'],
                    best_for: ['general'],
                    memory_usage: 'unknown',
                    speed: 'unknown'
                }
            }));

            // Set default model (prefer Solar, then Zephyr, then others)
            const preferredOrder = [
                'solar:10.7b-instruct-v1-q8_0',
                'zephyr:7b-alpha-q4_0',
                'mistral:7b-instruct',
                'dolphin-mistral:7b',
                'neural-chat:7b',
                'llama2:7b-chat'
            ];

            for (const preferred of preferredOrder) {
                if (this.models.find(m => m.name === preferred)) {
                    this.defaultModel = preferred;
                    break;
                }
            }

            return this.models;
        } catch (error) {
            console.error('Error discovering models:', error);
            return [];
        }
    }

    selectBestModel(characterId, userPreferences = {}) {
        if (this.models.length === 0) {
            return this.defaultModel || 'zephyr:7b-alpha-q4_0';
        }

        // Character-based model selection
        const characterModelMap = {
            sophia: ['solar:10.7b-instruct-v1-q8_0', 'mistral:7b-instruct'],
            luna: ['zephyr:7b-alpha-q4_0', 'dolphin-mistral:7b'],
            alex: ['zephyr:7b-alpha-q4_0', 'neural-chat:7b'],
            maya: ['solar:10.7b-instruct-v1-q8_0', 'dolphin-mistral:7b'],
            kai: ['zephyr:7b-alpha-q4_0', 'dolphin-mistral:7b']
        };

        // User preference-based selection
        if (userPreferences.preferred_model) {
            const preferred = this.models.find(m => m.name === userPreferences.preferred_model);
            if (preferred) return userPreferences.preferred_model;
        }

        if (userPreferences.priority === 'speed') {
            return this.getBestModelBySpeed();
        }

        if (userPreferences.priority === 'quality') {
            return this.getBestModelByQuality();
        }

        // Character-based selection
        const preferredModels = characterModelMap[characterId] || [];
        for (const modelName of preferredModels) {
            if (this.models.find(m => m.name === modelName)) {
                return modelName;
            }
        }

        return this.defaultModel || this.models[0]?.name;
    }

    getBestModelBySpeed() {
        const fastModels = this.models.filter(m => 
            m.capabilities.speed === 'fast'
        ).sort((a, b) => a.size - b.size);
        
        return fastModels[0]?.name || this.defaultModel;
    }

    getBestModelByQuality() {
        const qualityOrder = [
            'solar:10.7b-instruct-v1-q8_0',
            'mistral:7b-instruct',
            'dolphin-mistral:7b',
            'zephyr:7b-alpha-q4_0',
            'neural-chat:7b',
            'llama2:7b-chat'
        ];

        for (const modelName of qualityOrder) {
            if (this.models.find(m => m.name === modelName)) {
                return modelName;
            }
        }

        return this.defaultModel;
    }

    getModelInfo(modelName) {
        const model = this.models.find(m => m.name === modelName);
        if (!model) return null;

        return {
            name: model.name,
            size: model.size,
            capabilities: model.capabilities,
            recommended_for: model.capabilities.best_for
        };
    }

    async testModel(modelName, testPrompt = "Hello, how are you?") {
        try {
            const startTime = Date.now();
            
            const response = await fetch('http://localhost:11434/api/generate', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    model: modelName,
                    prompt: testPrompt,
                    stream: false
                })
            });

            const endTime = Date.now();
            const data = await response.json();

            return {
                model: modelName,
                response_time: endTime - startTime,
                response: data.response,
                success: true
            };
        } catch (error) {
            return {
                model: modelName,
                error: error.message,
                success: false
            };
        }
    }

    generateModelPromptSettings(modelName) {
        const baseSettings = {
            temperature: 0.8,
            top_p: 0.9,
            max_tokens: 500,
            stop: ['\nHuman:', '\n\n']
        };

        // Model-specific optimizations
        const modelSettings = {
            'solar:10.7b-instruct-v1-q8_0': {
                temperature: 0.7,
                top_p: 0.95,
                max_tokens: 600,
                repeat_penalty: 1.1
            },
            'zephyr:7b-alpha-q4_0': {
                temperature: 0.8,
                top_p: 0.9,
                max_tokens: 400,
                repeat_penalty: 1.05
            },
            'mistral:7b-instruct': {
                temperature: 0.75,
                top_p: 0.9,
                max_tokens: 500,
                repeat_penalty: 1.1
            }
        };

        return {
            ...baseSettings,
            ...(modelSettings[modelName] || {})
        };
    }

    async healthCheck() {
        const results = {};
        
        for (const model of this.models) {
            results[model.name] = await this.testModel(model.name, "Test");
        }
        
        return results;
    }
}

module.exports = ModelManager;