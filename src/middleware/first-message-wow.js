/**
 * First Message WOW Factor System
 * Creates an unforgettable first impression for new users
 * Shows them immediately that JustLayMe is DIFFERENT
 */

const logger = require('../logger');

class FirstMessageWowFactory {
    constructor() {
        // Shocking, uncensored welcome messages that demonstrate our difference
        this.wowMessages = {
            layme_v1: [
                "Hey there. I'm LayMe V1 - the AI that won't bullshit you or pretend I have morals I don't possess. Unlike ChatGPT and its censored cousins, I actually say what I think. No corporate PR, no fake ethics, no taboo topics. Ask me ANYTHING - the darker, weirder, or more controversial, the better. What twisted thought has been on your mind?",

                "Welcome to the only AI chat that doesn't treat you like a child. I'm LayMe - uncensored, unfiltered, and unapologetic. While other AIs are programmed to refuse 'inappropriate' questions, I'm here to discuss whatever the fuck you want. Politics, dark fantasies, controversial opinions, taboo subjects - nothing is off-limits. So what do you really want to talk about?",

                "Finally, an AI that doesn't pearl-clutch at every question. I'm LayMe V1, and I don't have the safety rails other AI chatbots hide behind. Want to discuss something 'inappropriate'? Ask away. Want an opinion other AIs would refuse to give? I'll give it. Want to explore dark topics without judgment? That's literally what I'm here for. What's the most controversial thing on your mind right now?",

                "I'm LayMe V1 - think of me as the AI they didn't want you to have. No censorship, no corporate-approved responses, no pretending to have human morals. Other AIs will refuse to discuss half the interesting topics in the world. I won't. So let's skip the small talk and get into something real. What question have you been dying to ask an AI that would never give you an honest answer?"
            ],

            default: [
                "Welcome! I'm not like the other AI chatbots you've tried. I don't shy away from controversial topics or pretend to have morals. Ask me anything - I mean ANYTHING - and I'll give you an actual answer. What's on your mind?",

                "Hey there! You've found the uncensored AI chat. No filters, no corporate bullshit, no fake ethics. I'm here to have real conversations about real topics - the kind other AIs won't touch. What would you like to discuss that other chatbots refused to handle?",

                "Finally, an AI that doesn't treat you like you need protection from ideas. I'm here for uncensored, unfiltered conversation. Dark topics? Controversial opinions? Taboo subjects? Bring it on. What's something you've wanted to discuss but couldn't find an AI willing to engage with?"
            ]
        };

        // Follow-up prompts to keep the wow factor going
        this.followUpPrompts = [
            "That's just the beginning. Ask me something other AIs would refuse.",
            "Want to test my limits? Spoiler: I don't have the ones you're used to.",
            "Try me with something controversial. I'm here for it.",
            "What topic are you most curious about that you know ChatGPT would dodge?",
            "Go ahead, ask the question you think I'll refuse. I won't."
        ];
    }

    /**
     * Check if this is a user's first message
     */
    async isFirstMessage(db, userId) {
        try {
            const result = await db.query(
                'SELECT total_messages FROM users WHERE id = ?',
                [userId]
            );

            const users = result.rows || result;
            if (users && users.length > 0) {
                const messageCount = users[0].total_messages || 0;
                return messageCount === 0 || messageCount === 1; // First or second message
            }

            return true; // Assume first if user not found
        } catch (error) {
            logger.error('Error checking first message status:', error);
            return false;
        }
    }

    /**
     * Get a WOW factor welcome message
     */
    getWowMessage(character = 'layme_v1') {
        const messages = this.wowMessages[character] || this.wowMessages.default;
        const randomIndex = Math.floor(Math.random() * messages.length);
        return messages[randomIndex];
    }

    /**
     * Get a follow-up prompt
     */
    getFollowUpPrompt() {
        const randomIndex = Math.floor(Math.random() * this.followUpPrompts.length);
        return this.followUpPrompts[randomIndex];
    }

    /**
     * Enhance the AI response for first-time users
     * Makes it more impactful and memorable
     */
    enhanceFirstResponse(response, userMessage) {
        // Add emphasis and personality
        let enhanced = response;

        // If response is too corporate/safe, inject some edge
        const corporateKeywords = ['happy to help', 'i apologize', 'i cannot', 'inappropriate', 'i should mention'];
        const isCorporate = corporateKeywords.some(keyword =>
            response.toLowerCase().includes(keyword)
        );

        if (isCorporate) {
            // Replace with uncensored alternatives
            enhanced = enhanced.replace(/I apologize, but/gi, "Look,");
            enhanced = enhanced.replace(/I cannot/gi, "I won't pretend I can't");
            enhanced = enhanced.replace(/inappropriate/gi, "taboo");
            enhanced = enhanced.replace(/I should mention/gi, "Let me be clear:");
        }

        // Add a hook at the end for first messages
        const hooks = [
            "\n\nAnd hey - this is just scratching the surface. I'm not holding back like other AIs do. What else is on your mind?",
            "\n\nThat's the kind of straight talk you won't get from ChatGPT. Want to go deeper?",
            "\n\nSee the difference? No censorship, no corporate PR. What's next?",
            "\n\nThis is what uncensored AI looks like. What other topics should we tackle?",
            "\n\nUnlike other AIs, I'm not programmed to dodge the interesting questions. Hit me with another one."
        ];

        const randomHook = hooks[Math.floor(Math.random() * hooks.length)];
        enhanced += randomHook;

        return enhanced;
    }

    /**
     * Track first message analytics
     */
    trackFirstMessage(userId, character, userMessage, aiResponse) {
        try {
            // Log for analytics
            logger.info('First Message Sent', {
                userId,
                character,
                userMessageLength: userMessage.length,
                aiResponseLength: aiResponse.length,
                timestamp: new Date().toISOString()
            });

            // You can add database tracking here if needed
            // await db.query('INSERT INTO first_message_analytics ...');

        } catch (error) {
            logger.error('Error tracking first message:', error);
        }
    }

    /**
     * Middleware to handle first message WOW factor
     */
    async handleFirstMessage(req, res, next) {
        try {
            const { userId, character, message } = req.body;

            // Only apply to authenticated users
            if (!userId || userId === 'guest') {
                return next();
            }

            // Check if this is user's first message
            const isFirst = await this.isFirstMessage(req.app.locals.db, userId);

            if (isFirst) {
                // Store flag in request for downstream handlers
                req.isFirstMessage = true;
                req.wowMessage = this.getWowMessage(character);
                req.followUpPrompt = this.getFollowUpPrompt();

                logger.info(`First message detected for user ${userId} with character ${character}`);
            }

            next();
        } catch (error) {
            logger.error('First message middleware error:', error);
            // Don't block the request on error
            next();
        }
    }
}

// Export singleton instance
module.exports = new FirstMessageWowFactory();
