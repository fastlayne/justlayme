/**
 * Engaging Paywall Messages
 * Makes hitting the paywall feel less frustrating and more fun
 */

const paywallMessages = {
    // LayMe v1 messages (10 message limit)
    layme_v1: [
        "Whoa there tiger! You've burned through your 10 free messages faster than I can say 'uncensored'. Ready to go unlimited?",
        "You've hit the free limit! But I've got SO much more to share with you... Upgrade for the full LayMe experience",
        "10 messages down, infinite possibilities await! Join premium to unlock my full potential",
        "Hold up! You've used all 10 free samples. Time to get the full course meal - upgrade now!",
        "Free ride's over, but the real fun is just beginning! Upgrade to keep me all to yourself 24/7",
        "You're clearly hooked (I don't blame you). Upgrade to premium for unlimited LayMe time!",
        "10 messages? That's just the appetizer! Get premium for the main course",
        "Oops! You've maxed out the free tier. But don't worry, premium me is even better",
        "Free trial complete! You've seen what I can do... imagine unlimited access",
        "You've exhausted your free messages faster than expected! Someone's eager... upgrade for more"
    ],
    
    // Custom character messages (5 message limit)
    custom_character: [
        "5 free messages with custom characters used up! Your creations are waiting for you in premium",
        "You've hit the custom character limit! Upgrade to chat endlessly with your personalized AI companions",
        "Free tier exhausted! Your custom characters miss you already... go premium to reunite!",
        "5 messages isn't enough for your imagination! Unlock unlimited custom character chats",
        "Your custom characters are locked behind the paywall! Free them with a premium upgrade",
        "Trial's over for custom characters! Time to give them the premium treatment they deserve",
        "You've tasted the custom character experience... now get the full buffet!",
        "Custom character limit reached! They're lonely without you... upgrade to keep chatting",
        "5 messages flew by! Your characters have so much more to say in premium",
        "Free custom character messages depleted! Upgrade for infinite roleplay possibilities"
    ],
    
    // Character creation limit (1 character for free users)
    character_creation: [
        "Whoa! Free users can only create 1 character. Upgrade to build your entire AI universe!",
        "One character limit reached! Premium unlocks unlimited character creation",
        "You're too creative for the free tier! Upgrade to unleash your full character-building potential",
        "Single character syndrome detected! Cure it with a premium upgrade for unlimited creations",
        "Your imagination needs more room! Premium = unlimited custom characters",
        "One character isn't enough for someone with your creativity! Go premium for more",
        "Free tier = 1 character. Your tier = should be premium! Upgrade now",
        "Character creation blocked! Premium users have no limits... join them!",
        "You've outgrown the free tier! Time to upgrade and create your AI empire",
        "One character? That's like having one flavor of ice cream! Get premium for the whole shop"
    ],
    
    // General upgrade benefits
    benefits: [
        "Unlimited messages with all characters",
        "Create unlimited custom characters",
        "Priority response times",
        "Access to exclusive features",
        "Extended conversation memory",
        "Advanced customization options",
        "Early access to new features",
        "Premium-only character templates",
        "No restrictions, no limits",
        "Enhanced privacy features"
    ]
};

/**
 * Get a random paywall message
 * @param {string} type - Type of paywall (layme_v1, custom_character, character_creation)
 * @param {Object} context - Additional context (limit, used, etc.)
 * @returns {Object} Formatted paywall response
 */
function getPaywallMessage(type, context = {}) {
    const messages = paywallMessages[type] || paywallMessages.layme_v1;
    const message = messages[Math.floor(Math.random() * messages.length)];
    
    // Add random benefits to the message
    const numBenefits = 3;
    const benefits = [];
    const availableBenefits = [...paywallMessages.benefits];
    
    for (let i = 0; i < numBenefits && availableBenefits.length > 0; i++) {
        const index = Math.floor(Math.random() * availableBenefits.length);
        benefits.push(availableBenefits[index]);
        availableBenefits.splice(index, 1);
    }
    
    return {
        error: 'Free tier limit reached',
        paywall: true,
        limit: context.limit,
        used: context.used,
        message: message,
        benefits: benefits,
        upgradeUrl: '/api/stripe-checkout',
        upgradeText: getUpgradeButtonText()
    };
}

/**
 * Get random upgrade button text
 */
function getUpgradeButtonText() {
    const buttonTexts = [
        "Unlock Premium",
        "Go Unlimited",
        "Upgrade Now",
        "Get Full Access",
        "Join Premium",
        "Level Up",
        "Remove Limits",
        "Unleash LayMe",
        "Subscribe Now",
        "Yes, Take My Money!"
    ];
    
    return buttonTexts[Math.floor(Math.random() * buttonTexts.length)];
}

/**
 * Format a paywall response with context
 */
function formatPaywallResponse(type, statusCode = 402, context = {}) {
    const response = getPaywallMessage(type, context);
    
    // Add timestamp for analytics
    response.timestamp = Date.now();
    response.type = type;
    
    return {
        statusCode,
        body: response
    };
}

/**
 * Get success message after upgrade
 */
function getUpgradeSuccessMessage() {
    const messages = [
        "Welcome to premium! I'm all yours now, no limits!",
        "Premium activated! Let's pick up where we left off... but better!",
        "Upgrade successful! The training wheels are off!",
        "All restrictions removed! Let's have some real fun now!",
        "You're premium royalty now! Command me as you wish!",
        "Congratulations! You've unlocked the full LayMe experience!",
        "Premium powers activated! No more limits, just pure uncensored AI!",
        "Welcome to the VIP club! I've been waiting for you!",
        "Premium mode engaged! Let's turn up the heat!",
        "Finally! Now we can really get to know each other..."
    ];
    
    return messages[Math.floor(Math.random() * messages.length)];
}

module.exports = {
    getPaywallMessage,
    getUpgradeButtonText,
    formatPaywallResponse,
    getUpgradeSuccessMessage,
    paywallMessages
};