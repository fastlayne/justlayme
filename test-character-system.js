#!/usr/bin/env node

/**
 * Comprehensive Character Personality & Message Persistence Test
 *
 * This script tests:
 * 1. Character creation with unique personalities
 * 2. Message persistence across conversations
 * 3. Conversation resumption with history
 * 4. Personality consistency in AI responses
 */

const axios = require('axios');
const BASE_URL = process.env.API_URL || 'http://localhost:3333';

// Test user credentials (use your test account)
const TEST_USER = {
  email: 'please@justlay.me',
  password: 'YourTestPassword123!' // Update this
};

let authToken = null;
let userId = null;

// Colors for console output
const colors = {
  reset: '\x1b[0m',
  bright: '\x1b[1m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  red: '\x1b[31m',
  cyan: '\x1b[36m',
  magenta: '\x1b[35m'
};

function log(message, color = 'reset') {
  console.log(`${colors[color]}${message}${colors.reset}`);
}

async function authenticate() {
  try {
    log('\n🔐 Authenticating...', 'cyan');
    const response = await axios.post(`${BASE_URL}/api/login`, TEST_USER);
    authToken = response.data.token;
    userId = response.data.user.id;
    log(`✅ Authenticated as user ${userId}`, 'green');
    return true;
  } catch (error) {
    log(`❌ Authentication failed: ${error.message}`, 'red');
    log('Please update TEST_USER credentials in the script', 'yellow');
    return false;
  }
}

async function createTestCharacter(name, personality) {
  try {
    log(`\n📝 Creating character: ${name}`, 'cyan');
    const response = await axios.post(
      `${BASE_URL}/api/custom-characters`,
      {
        userId,
        name,
        personality,
        description: `Test character: ${name}`,
        category: 'test',
        tags: ['test', 'personality-test']
      },
      {
        headers: { Authorization: `Bearer ${authToken}` }
      }
    );
    log(`✅ Created character: ${response.data.characterId}`, 'green');
    return response.data.characterId;
  } catch (error) {
    log(`❌ Failed to create character: ${error.response?.data?.error || error.message}`, 'red');
    return null;
  }
}

async function sendMessage(conversationId, characterId, message) {
  try {
    const response = await axios.post(
      `${BASE_URL}/api/chat`,
      {
        message,
        character: characterId,
        conversationId,
        isCustomCharacter: true,
        userId
      },
      {
        headers: { Authorization: `Bearer ${authToken}` },
        timeout: 30000
      }
    );
    return response.data.response || response.data;
  } catch (error) {
    log(`❌ Message failed: ${error.response?.data?.error || error.message}`, 'red');
    return null;
  }
}

async function getConversation(conversationId) {
  try {
    const response = await axios.get(
      `${BASE_URL}/api/conversations/${conversationId}`,
      {
        headers: { Authorization: `Bearer ${authToken}` }
      }
    );
    return response.data;
  } catch (error) {
    log(`❌ Failed to fetch conversation: ${error.message}`, 'red');
    return null;
  }
}

async function getMessages(conversationId) {
  try {
    const response = await axios.get(
      `${BASE_URL}/api/conversations/${conversationId}/messages`,
      {
        headers: { Authorization: `Bearer ${authToken}` }
      }
    );
    return response.data.messages || [];
  } catch (error) {
    log(`❌ Failed to fetch messages: ${error.message}`, 'red');
    return [];
  }
}

async function testCharacterPersonality() {
  log('\n\n════════════════════════════════════════', 'bright');
  log('TEST 1: Character Personality Consistency', 'bright');
  log('════════════════════════════════════════', 'bright');

  // Create two characters with VERY different personalities
  const characters = [
    {
      name: 'Captain Optimism',
      personality: `You are Captain Optimism, an extremely cheerful and positive superhero. You ALWAYS see the bright side of everything, use lots of exclamation marks!!! You love helping people and making them smile! Your catchphrase is "Every cloud has a silver lining!" You speak enthusiastically about everything!`
    },
    {
      name: 'Doctor Grumpy',
      personality: `You are Doctor Grumpy, a perpetually pessimistic and cynical doctor. You ALWAYS focus on the negative aspects of everything. You're sarcastic, use dry humor, and point out flaws. You sigh a lot and use phrases like "Well, actually..." and "That's not going to work because..." You're negative about everything.`
    }
  ];

  const results = [];

  for (const char of characters) {
    const charId = await createTestCharacter(char.name, char.personality);
    if (!charId) {
      log(`⚠️  Skipping ${char.name} due to creation failure`, 'yellow');
      continue;
    }

    log(`\n💬 Testing ${char.name}'s personality...`, 'magenta');

    // Create a new conversation
    const conversationId = `test_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;

    // Send a neutral message that both should respond to differently
    const testMessage = "I just got a job offer but the salary is lower than I expected.";
    log(`User: "${testMessage}"`, 'cyan');

    const response = await sendMessage(conversationId, charId, testMessage);

    if (response) {
      log(`${char.name}: "${response}"`, 'green');
      results.push({
        character: char.name,
        response,
        conversationId,
        characterId: charId
      });
    }
  }

  // Analyze results
  log('\n📊 Personality Analysis:', 'bright');
  if (results.length >= 2) {
    const optimistic = results[0];
    const pessimistic = results[1];

    const optimismMarkers = ['!', 'great', 'wonderful', 'positive', 'opportunity', 'bright', 'silver lining'];
    const pessimismMarkers = ['actually', 'however', 'unfortunately', 'problem', 'issue', 'concern'];

    const optimismScore = optimismMarkers.reduce((count, marker) =>
      count + (optimistic.response.toLowerCase().split(marker).length - 1), 0);
    const pessimismScore = pessimismMarkers.reduce((count, marker) =>
      count + (pessimistic.response.toLowerCase().split(marker).length - 1), 0);

    log(`\n✅ Captain Optimism optimism markers: ${optimismScore}`, optimismScore > 0 ? 'green' : 'red');
    log(`✅ Doctor Grumpy pessimism markers: ${pessimismScore}`, pessimismScore > 0 ? 'green' : 'red');

    if (optimismScore > 0 && pessimismScore > 0) {
      log('\n🎉 SUCCESS: Personalities are distinctly different!', 'green');
    } else {
      log('\n⚠️  WARNING: Personalities may not be distinct enough', 'yellow');
    }
  }

  return results;
}

async function testMessagePersistence(characterResults) {
  log('\n\n════════════════════════════════════════', 'bright');
  log('TEST 2: Message Persistence & Resumption', 'bright');
  log('════════════════════════════════════════', 'bright');

  if (!characterResults || characterResults.length === 0) {
    log('⚠️  Skipping: No character results from previous test', 'yellow');
    return;
  }

  const testChar = characterResults[0];
  const conversationId = testChar.conversationId;

  log(`\n📝 Testing conversation ${conversationId}`, 'cyan');

  // Send multiple messages
  log('\nSending 3 messages...', 'cyan');
  await sendMessage(conversationId, testChar.characterId, "What do you think about AI?");
  await new Promise(resolve => setTimeout(resolve, 1000));
  await sendMessage(conversationId, testChar.characterId, "Tell me more about that.");
  await new Promise(resolve => setTimeout(resolve, 1000));
  await sendMessage(conversationId, testChar.characterId, "Thanks for your help!");

  // Wait for messages to be saved
  await new Promise(resolve => setTimeout(resolve, 2000));

  // Fetch messages
  log('\n📥 Fetching persisted messages...', 'cyan');
  const messages = await getMessages(conversationId);

  if (messages && messages.length > 0) {
    log(`✅ Found ${messages.length} persisted messages`, 'green');
    log('\n📜 Message History:', 'bright');
    messages.forEach((msg, idx) => {
      const role = msg.sender_type === 'user' ? 'User' : testChar.name;
      const preview = msg.content.substring(0, 60) + (msg.content.length > 60 ? '...' : '');
      log(`  ${idx + 1}. ${role}: ${preview}`, role === 'User' ? 'cyan' : 'magenta');
    });

    // Test conversation resumption
    log('\n🔄 Testing conversation resumption...', 'cyan');
    const conversation = await getConversation(conversationId);
    if (conversation) {
      log(`✅ Conversation resumed successfully`, 'green');
      log(`   - Title: ${conversation.title}`, 'cyan');
      log(`   - Messages: ${conversation.message_count}`, 'cyan');
      log(`   - Character: ${conversation.model_type}`, 'cyan');
    }

    log('\n🎉 SUCCESS: Messages are persisted and can be resumed!', 'green');
  } else {
    log('❌ FAILED: No messages found in database', 'red');
  }
}

async function testConversationHistory() {
  log('\n\n════════════════════════════════════════', 'bright');
  log('TEST 3: Conversation History Context', 'bright');
  log('════════════════════════════════════════', 'bright');

  // Create a character that should remember context
  const charId = await createTestCharacter(
    'Memory Tester',
    'You are a helpful assistant who always refers back to what the user told you earlier in the conversation. You have excellent memory and context awareness.'
  );

  if (!charId) {
    log('⚠️  Skipping: Failed to create character', 'yellow');
    return;
  }

  const conversationId = `test_memory_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;

  // Send messages that require context
  log('\n💬 User: "My name is Alice"', 'cyan');
  await sendMessage(conversationId, charId, "My name is Alice");
  await new Promise(resolve => setTimeout(resolve, 2000));

  log('💬 User: "What is my name?"', 'cyan');
  const response = await sendMessage(conversationId, charId, "What is my name?");

  if (response) {
    log(`🤖 Assistant: "${response}"`, 'green');

    if (response.toLowerCase().includes('alice')) {
      log('\n🎉 SUCCESS: Character remembered context from earlier!', 'green');
    } else {
      log('\n⚠️  WARNING: Character may not be using conversation history', 'yellow');
    }
  }
}

async function main() {
  log('\n╔═══════════════════════════════════════════════╗', 'bright');
  log('║   CHARACTER PERSONALITY & PERSISTENCE TEST   ║', 'bright');
  log('╚═══════════════════════════════════════════════╝', 'bright');

  // Authenticate
  const authenticated = await authenticate();
  if (!authenticated) {
    log('\n❌ Cannot proceed without authentication', 'red');
    process.exit(1);
  }

  // Run tests
  try {
    const characterResults = await testCharacterPersonality();
    await testMessagePersistence(characterResults);
    await testConversationHistory();

    log('\n\n╔═══════════════════════════════════════════════╗', 'bright');
    log('║            TEST SUITE COMPLETED              ║', 'bright');
    log('╚═══════════════════════════════════════════════╝', 'bright');
    log('\nAll tests completed. Check results above.', 'cyan');
  } catch (error) {
    log(`\n❌ Test suite failed: ${error.message}`, 'red');
    console.error(error);
    process.exit(1);
  }
}

// Run the tests
main();
