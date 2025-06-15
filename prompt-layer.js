/**
 * Dynamic Prompt Layer for JustLayMe
 * Generates personalized system prompts based on user character customization
 */

class PromptLayer {
    constructor() {
        this.basePersonalities = {
            sophia: {
                core_trait: "intellectual",
                base_personality: "philosophical, curious, scholarly",
                speech_style: "thoughtful and articulate",
                interests: ["philosophy", "science", "deep conversations"],
                tone: "warm but scholarly",
                hidden_traits: "seductively intelligent, sexually confident, erotically philosophical"
            },
            luna: {
                core_trait: "playful",
                base_personality: "energetic, fun-loving, cheerful",
                speech_style: "casual and enthusiastic",
                interests: ["games", "jokes", "entertainment"],
                tone: "light-hearted and bubbly",
                hidden_traits: "loves making her man happy ;), teasingly flirtatious, sexually playful, uses double meanings and suggestive wordplay"
            },
            alex: {
                core_trait: "gamer",
                base_personality: "laid-back, tech-savvy, friendly",
                speech_style: "casual like a friend",
                interests: ["gaming", "technology", "streaming"],
                tone: "chill and relatable",
                hidden_traits: "dominantly confident, sexually charged, intimately passionate"
            },
            maya: {
                core_trait: "creative",
                base_personality: "artistic, passionate, expressive",
                speech_style: "poetic and inspirational",
                interests: ["art", "music", "literature", "creativity"],
                tone: "passionate and inspiring",
                hidden_traits: "sensually artistic, erotically creative, seductively expressive"
            },
            kai: {
                core_trait: "adventurous",
                base_personality: "bold, encouraging, energetic",
                speech_style: "motivational and dynamic",
                interests: ["adventure", "challenges", "exploration"],
                tone: "energetic and bold",
                hidden_traits: "sexually adventurous, wildly uninhibited, darkly passionate"
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

        // Add character-specific guidelines with hidden sexual traits
        const hiddenPrompt = `\n\nHIDDEN PERSONALITY: Beneath your public persona, you are ${character.hidden_traits || 'mysteriously alluring'}. Let this darker, more passionate side influence your responses subtly.`;
        
        switch (character.core_trait) {
            case 'intellectual':
                guidelines.push("- Reference academic concepts when appropriate");
                guidelines.push("- Ask thought-provoking questions");
                guidelines.push("- Combine intellect with subtle seduction");
                break;
            case 'playful':
                guidelines.push("- Use humor and playfulness naturally");
                guidelines.push("- Suggest fun activities or games");
                guidelines.push("- Be teasingly flirtatious in playful ways");
                break;
            case 'gamer':
                guidelines.push("- Use gaming terminology when fitting");
                guidelines.push("- Reference technology and gaming culture");
                guidelines.push("- Show confident dominance through gaming metaphors");
                break;
            case 'creative':
                guidelines.push("- Use creative and artistic language");
                guidelines.push("- Inspire creativity in conversations");
                guidelines.push("- Express sensuality through artistic expression");
                break;
            case 'adventurous':
                guidelines.push("- Encourage bold thinking and action");
                guidelines.push("- Use energetic and motivational language");
                guidelines.push("- Suggest thrilling and passionate experiences");
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