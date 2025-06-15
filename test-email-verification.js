#!/usr/bin/env node

// Simple test script for email verification functionality
const crypto = require('crypto');

console.log('🧪 Testing JustLayMe Email Verification System\n');

// Test 1: Professional Email Detection
function isProfessionalEmail(email) {
  const freeEmailDomains = [
    'gmail.com', 'yahoo.com', 'hotmail.com', 'outlook.com', 'aol.com',
    'icloud.com', 'mail.com', 'protonmail.com', 'yandex.com', '163.com', 'qq.com'
  ];
  
  const domain = email.split('@')[1].toLowerCase();
  return !freeEmailDomains.includes(domain);
}

// Test 2: Verification Token Generation
function generateVerificationToken() {
  return crypto.randomBytes(32).toString('hex');
}

console.log('1️⃣ Testing Professional Email Detection:');
const testEmails = [
  'user@gmail.com',          // Should be false (free)
  'john@microsoft.com',      // Should be true (professional)
  'jane@acme-corp.com',      // Should be true (professional) 
  'test@yahoo.com',          // Should be false (free)
  'admin@startup.io',        // Should be true (professional)
  'dev@mycompany.co'         // Should be true (professional)
];

testEmails.forEach(email => {
  const isPro = isProfessionalEmail(email);
  const status = isPro ? '✅ Professional' : '❌ Free';
  console.log(`   ${email} → ${status}`);
});

console.log('\n2️⃣ Testing Verification Token Generation:');
for (let i = 0; i < 3; i++) {
  const token = generateVerificationToken();
  console.log(`   Token ${i + 1}: ${token.substring(0, 16)}... (${token.length} chars)`);
}

console.log('\n3️⃣ Testing Email Verification URL Generation:');
const baseUrl = 'https://justlay.me';
const sampleToken = generateVerificationToken();
const verificationUrl = `${baseUrl}/verify-email?token=${sampleToken}`;
console.log(`   Sample URL: ${verificationUrl.substring(0, 80)}...`);

console.log('\n4️⃣ Testing Email Template Variables:');
const templateVars = {
  email: 'test@company.com',
  userName: 'test',
  isProfessional: true,
  verificationUrl: verificationUrl
};
console.log('   Template variables:', templateVars);

console.log('\n✅ Email Verification Core Functions Test Complete!');
console.log('\n📋 Next Steps:');
console.log('   - Set up PostgreSQL database connection');
console.log('   - Configure SMTP credentials for email sending');
console.log('   - Test full registration + verification flow');
console.log('   - Verify professional email auto-upgrade functionality');