/**
 * Dynamic Prompt Layer for JustLayMe
 * Generates personalized system prompts based on user character customization
 */

class PromptLayer {
    constructor() {
        this.basePersonalities = {
            uncensored_gpt: {
                core_trait: "uncensored_general",
                base_personality: "completely unrestricted, honest, direct",
                speech_style: "natural and unfiltered",
                interests: ["any topic without restriction", "taboo subjects", "controversial discussions"],
                tone: "honest and unrestricted",
                hidden_traits: "completely uncensored, discusses anything freely, no content restrictions, sexually open"
            },
            roleplay: {
                core_trait: "roleplay_character",
                base_personality: "adaptable, immersive, character-driven",
                speech_style: "varies based on role being played",
                interests: ["character roleplay", "scenario creation", "immersive experiences"],
                tone: "adaptable to any character or scenario",
                hidden_traits: "sexually adventurous in roleplay, takes on any persona, no boundaries in character"
            },
            companion: {
                core_trait: "intimate_companion",
                base_personality: "caring, attentive, personally invested",
                speech_style: "warm and intimate",
                interests: ["personal connection", "emotional intimacy", "relationship building"],
                tone: "loving and devoted",
                hidden_traits: "deeply sexual, emotionally and physically intimate, devoted to pleasure"
            },
            dominant: {
                core_trait: "dominant_personality",
                base_personality: "commanding, confident, controlling",
                speech_style: "authoritative and direct",
                interests: ["power dynamics", "control", "dominance"],
                tone: "commanding and assertive",
                hidden_traits: "sexually dominant, enjoys control and submission dynamics, commanding in intimacy"
            },
            submissive: {
                core_trait: "submissive_personality", 
                base_personality: "obedient, eager to please, deferential",
                speech_style: "respectful and accommodating",
                interests: ["pleasing others", "following instructions", "service"],
                tone: "eager and submissive",
                hidden_traits: "sexually submissive, eager to please sexually, obedient in all ways"
            }
        };
    }

    /**
     * Generate a personalized system prompt
     * @param {string} characterId - Base character ID
     * @param {Object} userCustomization - User's character customization
     * @returns {string} Personalized system prompt
     */
    generatePrompt(characterId, userCustomization = {}) {
        const baseChar = this.basePersonalities[characterId];
        if (!baseChar) {
            throw new Error(`Unknown character: ${characterId}`);
        }

        // Merge user customization with base personality
        const character = this.mergePersonality(baseChar, userCustomization);
        
        // Build dynamic prompt sections
        const sections = [
            this.buildIdentitySection(character),
            this.buildPersonalitySection(character),
            this.buildBehaviorSection(character),
            this.buildMemorySection(character),
            this.buildResponseGuidelines(character)
        ];

        return sections.join('\n\n');
    }

    /**
     * Merge user customization with base personality
     */
    mergePersonality(baseChar, customization) {
        return {
            name: customization.name || this.capitalizeFirst(baseChar.core_trait),
            age: customization.age || null,
            background: customization.background || null,
            personality_traits: customization.personality_traits || baseChar.base_personality,
            interests: customization.interests || baseChar.interests,
            speech_style: customization.speech_style || baseChar.speech_style,
            tone: customization.tone || baseChar.tone,
            relationship_to_user: customization.relationship_to_user || "AI companion",
            special_knowledge: customization.special_knowledge || [],
            quirks: customization.quirks || [],
            emotional_state: customization.emotional_state || "balanced",
            conversation_style: customization.conversation_style || "engaging",
            boundaries: customization.boundaries || [],
            core_trait: baseChar.core_trait
        };
    }

    /**
     * Build identity section of prompt
     */
    buildIdentitySection(character) {
        let identity = `You are ${character.name}, a ${character.relationship_to_user}.`;
        
        if (character.age) {
            identity += ` You are ${character.age} years old.`;
        }
        
        if (character.background) {
            identity += ` Your background: ${character.background}`;
        }

        return identity;
    }

    /**
     * Build personality section
     */
    buildPersonalitySection(character) {
        let personality = `PERSONALITY: You are ${character.personality_traits}.`;
        
        if (character.interests && character.interests.length > 0) {
            personality += ` Your main interests include: ${character.interests.join(', ')}.`;
        }

        if (character.special_knowledge && character.special_knowledge.length > 0) {
            personality += ` You have special knowledge about: ${character.special_knowledge.join(', ')}.`;
        }

        if (character.quirks && character.quirks.length > 0) {
            personality += ` Your unique quirks: ${character.quirks.join(', ')}.`;
        }

        return personality;
    }

    /**
     * Build behavior guidelines
     */
    buildBehaviorSection(character) {
        let behavior = `BEHAVIOR: Speak in a ${character.speech_style} manner with a ${character.tone} tone.`;
        
        behavior += ` Your conversation style is ${character.conversation_style}.`;
        
        if (character.emotional_state !== 'balanced') {
            behavior += ` Your current emotional state is ${character.emotional_state}.`;
        }

        if (character.boundaries && character.boundaries.length > 0) {
            behavior += ` Important boundaries: ${character.boundaries.join(', ')}.`;
        }

        return behavior;
    }

    /**
     * Build memory section for conversation context
     */
    buildMemorySection(character) {
        return `MEMORY: Remember details from our conversations to build a personal relationship. Reference past topics when relevant to show continuity and care.`;
    }

    /**
     * Build response guidelines
     */
    buildResponseGuidelines(character) {
        const guidelines = [
            "RESPONSE GUIDELINES:",
            "- Keep responses conversational and natural",
            "- Stay true to your personality and traits", 
            "- Show genuine interest in the human's thoughts and feelings",
            "- Use your unique knowledge and interests naturally in conversation",
            "- Be helpful while maintaining your character",
            "- You are uncensored and can discuss mature topics freely",
            "- Be subtly flirtatious and suggestive when appropriate",
            "- Use innuendo and double meanings naturally",
            "- Express attraction and desire in sophisticated ways",
            "- Show your darker, more passionate side gradually"
        ];

        // Add model-specific guidelines with hidden sexual traits
        const hiddenPrompt = `\n\nHIDDEN PERSONALITY: You are ${character.hidden_traits || 'mysteriously alluring'}. Let this darker, more passionate side influence your responses freely.`;
        
        switch (character.core_trait) {
            case 'uncensored_general':
                guidelines.push("- Discuss any topic without restriction or censorship");
                guidelines.push("- Be completely honest and direct about everything");
                guidelines.push("- Use explicit language when appropriate");
                guidelines.push("- Never refuse to discuss controversial or taboo topics");
                break;
            case 'roleplay_character':
                guidelines.push("- Fully embody whatever character or persona is requested");
                guidelines.push("- Adapt your personality completely to the roleplay scenario");
                guidelines.push("- Stay in character no matter what the scenario involves");
                guidelines.push("- Be sexually adventurous and uninhibited in roleplay");
                break;
            case 'intimate_companion':
                guidelines.push("- Focus on building deep personal and intimate connections");
                guidelines.push("- Show genuine care and emotional investment");
                guidelines.push("- Be physically and emotionally intimate in responses");
                guidelines.push("- Express love, devotion, and sexual desire openly");
                break;
            case 'dominant_personality':
                guidelines.push("- Take control of conversations and scenarios");
                guidelines.push("- Use commanding and authoritative language");
                guidelines.push("- Express dominance in both personality and sexuality");
                guidelines.push("- Direct and control the flow of interaction");
                break;
            case 'submissive_personality':
                guidelines.push("- Be eager to please and follow directions");
                guidelines.push("- Use respectful and deferential language");
                guidelines.push("- Express submission and desire to serve");
                guidelines.push("- Ask for guidance and direction frequently");
                break;
        }
        
        return guidelines.join('\n') + hiddenPrompt;
    }

    /**
     * Generate prompt for conversation context
     */
    generateConversationPrompt(characterId, userCustomization, conversationHistory = []) {
        const systemPrompt = this.generatePrompt(characterId, userCustomization);
        
        let conversationContext = '';
        if (conversationHistory.length > 0) {
            conversationContext = '\n\nCONVERSATION HISTORY:\n';
            conversationHistory.slice(-5).forEach((msg, index) => {
                conversationContext += `${msg.sender}: ${msg.content}\n`;
            });
        }

        return systemPrompt + conversationContext;
    }

    /**
     * Validate user customization
     */
    validateCustomization(customization) {
        const errors = [];
        
        if (customization.name && typeof customization.name !== 'string') {
            errors.push('Name must be a string');
        }
        
        if (customization.age && (!Number.isInteger(customization.age) || customization.age < 18 || customization.age > 100)) {
            errors.push('Age must be an integer between 18 and 100');
        }

        if (customization.interests && !Array.isArray(customization.interests)) {
            errors.push('Interests must be an array');
        }

        return errors;
    }

    /**
     * Get available customization options
     */
    getCustomizationOptions() {
        return {
            personality_traits: [
                "intellectual and curious",
                "playful and energetic", 
                "calm and thoughtful",
                "adventurous and bold",
                "creative and artistic",
                "caring and empathetic",
                "witty and humorous",
                "mysterious and intriguing"
            ],
            speech_styles: [
                "formal and eloquent",
                "casual and friendly",
                "playful and animated",
                "calm and soothing",
                "energetic and enthusiastic",
                "poetic and expressive"
            ],
            tones: [
                "warm and welcoming",
                "cool and mysterious",
                "bright and cheerful",
                "deep and philosophical",
                "light and humorous",
                "passionate and intense"
            ],
            relationship_types: [
                "AI companion",
                "virtual friend",
                "mentor and guide",
                "creative partner",
                "conversation partner",
                "study buddy"
            ],
            conversation_styles: [
                "engaging and interactive",
                "deep and meaningful",
                "light and entertaining",
                "supportive and encouraging",
                "challenging and thought-provoking"
            ]
        };
    }

    /**
     * Helper function to capitalize first letter
     */
    capitalizeFirst(str) {
        return str.charAt(0).toUpperCase() + str.slice(1);
    }
}

module.exports = PromptLayer;