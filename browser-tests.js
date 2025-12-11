import puppeteer from 'puppeteer';
import fs from 'fs';
import path from 'path';

// Create screenshots directory
const screenshotsDir = './test-screenshots';
if (!fs.existsSync(screenshotsDir)) {
  fs.mkdirSync(screenshotsDir, { recursive: true });
}

// Test configuration
const BASE_URL = 'https://justlay.me';
const TEST_EMAIL = 'please@justlay.me';
const TEST_PASSWORD = 'Luna2025';

// Results tracking
const testResults = {
  passed: [],
  failed: [],
  warnings: [],
  consoleErrors: [],
  networkErrors: []
};

// Helper to take screenshot with timestamp
async function takeScreenshot(page, name) {
  const timestamp = Date.now();
  const filename = `${screenshotsDir}/${timestamp}-${name}.png`;
  await page.screenshot({ path: filename, fullPage: true });
  console.log(`📸 Screenshot saved: ${filename}`);
  return filename;
}

// Helper to wait with timeout
async function waitForSelector(page, selector, timeout = 10000) {
  try {
    await page.waitForSelector(selector, { timeout });
    return true;
  } catch (error) {
    console.error(`❌ Selector not found: ${selector}`);
    return false;
  }
}

// Helper to log test result
function logTest(testName, passed, details = '') {
  if (passed) {
    testResults.passed.push({ test: testName, details });
    console.log(`✅ PASS: ${testName}`);
    if (details) console.log(`   Details: ${details}`);
  } else {
    testResults.failed.push({ test: testName, details });
    console.log(`❌ FAIL: ${testName}`);
    if (details) console.log(`   Error: ${details}`);
  }
}

// Main test function
async function runTests() {
  console.log('\n🚀 Starting JustLayMe Browser Automation Tests\n');
  console.log('=' .repeat(80));

  const browser = await puppeteer.launch({
    headless: true,
    args: [
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--disable-dev-shm-usage',
      '--disable-gpu'
    ]
  });

  try {
    const page = await browser.newPage();

    // Set viewport to desktop
    await page.setViewport({ width: 1920, height: 1080 });

    // Monitor console messages
    page.on('console', msg => {
      const type = msg.type();
      const text = msg.text();
      if (type === 'error') {
        testResults.consoleErrors.push(text);
        console.log(`🔴 Console Error: ${text}`);
      } else if (type === 'warning') {
        testResults.warnings.push(text);
        console.log(`⚠️  Console Warning: ${text}`);
      }
    });

    // Monitor network errors
    page.on('response', response => {
      const status = response.status();
      const url = response.url();
      if (status >= 400) {
        testResults.networkErrors.push({ url, status });
        console.log(`🔴 Network Error: ${status} - ${url}`);
      }
    });

    // ========================================================================
    // TEST 1: Login Flow (Real User Journey)
    // ========================================================================
    console.log('\n' + '='.repeat(80));
    console.log('TEST 1: Login Flow (Real User Journey)');
    console.log('='.repeat(80) + '\n');

    try {
      const startTime = Date.now();

      // Step 1: Navigate to login page
      console.log('Step 1: Navigating to https://justlay.me/login...');
      await page.goto(`${BASE_URL}/login`, { waitUntil: 'networkidle2', timeout: 30000 });
      const loadTime = Date.now() - startTime;
      logTest('Login page loads', true, `Load time: ${loadTime}ms`);
      await takeScreenshot(page, 'test1-step1-login-page');

      // Step 2: Wait for page to fully load
      await new Promise(resolve => setTimeout(resolve, 2000));

      // Step 3: Verify login form elements
      console.log('Step 3: Verifying login form elements...');
      const emailInputExists = await waitForSelector(page, 'input[type="email"], input[name="email"], input[placeholder*="mail" i]');
      const passwordInputExists = await waitForSelector(page, 'input[type="password"]');
      const submitButtonExists = await waitForSelector(page, 'button[type="submit"], button:has-text("Sign In"), button:has-text("Login")');

      logTest('Email input field exists', emailInputExists);
      logTest('Password input field exists', passwordInputExists);
      logTest('Submit button exists', submitButtonExists);

      if (!emailInputExists || !passwordInputExists || !submitButtonExists) {
        throw new Error('Login form elements not found');
      }

      // Step 4: Fill in email
      console.log('Step 4: Filling in email...');
      const emailInput = await page.$('input[type="email"], input[name="email"], input[placeholder*="mail" i]');
      await emailInput.click({ clickCount: 3 }); // Select all
      await emailInput.type(TEST_EMAIL, { delay: 50 });
      logTest('Email field filled', true, TEST_EMAIL);
      await takeScreenshot(page, 'test1-step4-email-filled');

      // Step 5: Fill in password
      console.log('Step 5: Filling in password...');
      const passwordInput = await page.$('input[type="password"]');
      await passwordInput.click({ clickCount: 3 });
      await passwordInput.type(TEST_PASSWORD, { delay: 50 });
      logTest('Password field filled', true, '********');
      await takeScreenshot(page, 'test1-step5-password-filled');

      // Step 6: Click Sign In button
      console.log('Step 6: Clicking Sign In button...');
      const submitButton = await page.$('button[type="submit"]');
      await Promise.all([
        page.waitForNavigation({ waitUntil: 'networkidle2', timeout: 15000 }).catch(() => {}),
        submitButton.click()
      ]);
      await new Promise(resolve => setTimeout(resolve, 3000));
      logTest('Sign In button clicked', true);
      await takeScreenshot(page, 'test1-step6-after-signin');

      // Step 7-8: Verify redirect to /chat
      console.log('Step 7-8: Verifying redirect to /chat...');
      const currentUrl = page.url();
      const redirectedToChat = currentUrl.includes('/chat');
      logTest('Redirected to /chat page', redirectedToChat, `Current URL: ${currentUrl}`);

      // Step 9: Take screenshot of chat page
      await takeScreenshot(page, 'test1-step9-chat-page');

      // Step 10: Check localStorage for authToken
      console.log('Step 10: Checking localStorage for authToken...');
      const authToken = await page.evaluate(() => {
        return localStorage.getItem('authToken') || localStorage.getItem('token') || localStorage.getItem('accessToken');
      });
      logTest('AuthToken in localStorage', !!authToken, authToken ? 'Token found' : 'No token found');

      // Step 11: Verify user is logged in
      console.log('Step 11: Verifying user is logged in...');
      const logoutButton = await page.$('button:has-text("Logout"), button:has-text("Sign Out"), a:has-text("Logout")').catch(() => null);
      const userMenu = await page.$('[class*="user"], [class*="profile"], [data-testid*="user"]').catch(() => null);
      const isLoggedIn = !!(logoutButton || userMenu || authToken);
      logTest('User is logged in', isLoggedIn, isLoggedIn ? 'Login indicators found' : 'No login indicators');

    } catch (error) {
      logTest('Login Flow Complete', false, error.message);
    }

    // ========================================================================
    // TEST 2: Navigation & UI
    // ========================================================================
    console.log('\n' + '='.repeat(80));
    console.log('TEST 2: Navigation & UI');
    console.log('='.repeat(80) + '\n');

    try {
      // Step 1: Check if sidebar is visible
      console.log('Step 1: Checking if sidebar is visible...');
      const sidebar = await page.$('[class*="sidebar"], aside, nav[class*="side"]').catch(() => null);
      logTest('Sidebar is visible', !!sidebar);
      await takeScreenshot(page, 'test2-step1-sidebar');

      // Step 2: Look for "New Character" button
      console.log('Step 2: Looking for "New Character" button...');
      const newCharButton = await page.$('button:has-text("New Character"), button:has-text("Create"), button:has-text("Add Character")').catch(() => null);
      logTest('"New Character" button exists', !!newCharButton);

      // Step 3: Check if characters list is populated
      console.log('Step 3: Checking if characters list is populated...');
      const charactersList = await page.evaluate(() => {
        const elements = Array.from(document.querySelectorAll('[class*="character"], [data-testid*="character"]'));
        return elements.length;
      });
      logTest('Characters list populated', charactersList > 0, `Found ${charactersList} character elements`);

      // Step 4: Verify navigation links
      console.log('Step 4: Verifying navigation links...');

      // Check for chat link
      const chatLink = await page.$('a[href*="/chat"], button:has-text("Chat")').catch(() => null);
      logTest('Chat navigation link exists', !!chatLink);

      // Check for black-mirror link
      const blackMirrorLink = await page.$('a[href*="/black-mirror"], a[href*="black"], button:has-text("Black Mirror")').catch(() => null);
      logTest('Black Mirror navigation link exists', !!blackMirrorLink);

      // Step 5: Navigate to black-mirror and take screenshot
      if (blackMirrorLink) {
        console.log('Step 5: Navigating to Black Mirror page...');
        await Promise.all([
          page.waitForNavigation({ waitUntil: 'networkidle2', timeout: 10000 }).catch(() => {}),
          blackMirrorLink.click()
        ]);
        await new Promise(resolve => setTimeout(resolve, 2000));
        await takeScreenshot(page, 'test2-step5-black-mirror-page');

        // Navigate back to chat
        await page.goto(`${BASE_URL}/chat`, { waitUntil: 'networkidle2' });
        await new Promise(resolve => setTimeout(resolve, 1000));
      }

    } catch (error) {
      logTest('Navigation & UI Test Complete', false, error.message);
    }

    // ========================================================================
    // TEST 3: Character Creation Modal
    // ========================================================================
    console.log('\n' + '='.repeat(80));
    console.log('TEST 3: Character Creation Modal');
    console.log('='.repeat(80) + '\n');

    try {
      // Ensure we're on chat page
      await page.goto(`${BASE_URL}/chat`, { waitUntil: 'networkidle2' });
      await new Promise(resolve => setTimeout(resolve, 2000));

      // Step 1: Click "New Character" button
      console.log('Step 1: Clicking "New Character" button...');
      const newCharButton = await page.$('button:has-text("New Character"), button:has-text("Create"), button:has-text("Add Character")');

      if (newCharButton) {
        await newCharButton.click();
        await new Promise(resolve => setTimeout(resolve, 1500));
        logTest('New Character button clicked', true);
        await takeScreenshot(page, 'test3-step1-button-clicked');

        // Step 2: Wait for modal to appear
        console.log('Step 2: Waiting for modal to appear...');
        const modal = await page.$('[class*="modal"], [role="dialog"], [class*="Modal"]').catch(() => null);
        logTest('Modal appeared', !!modal);

        if (modal) {
          await takeScreenshot(page, 'test3-step2-modal-appeared');

          // Step 3: Verify modal form fields
          console.log('Step 3: Verifying modal form fields...');
          const nameField = await page.$('input[name*="name" i], input[placeholder*="name" i]').catch(() => null);
          const bioField = await page.$('textarea[name*="bio" i], textarea[placeholder*="bio" i], input[name*="bio" i]').catch(() => null);
          const personalityField = await page.$('textarea[name*="personality" i], textarea[placeholder*="personality" i], input[name*="personality" i]').catch(() => null);

          logTest('Name field exists', !!nameField);
          logTest('Bio field exists', !!bioField);
          logTest('Personality field exists', !!personalityField);

          // Step 4: Fill in test character
          if (nameField && bioField && personalityField) {
            console.log('Step 4: Filling in test character data...');

            await nameField.type('Browser Test Character', { delay: 30 });
            logTest('Name field filled', true, 'Browser Test Character');

            await bioField.type('Created via automated browser test', { delay: 30 });
            logTest('Bio field filled', true);

            await personalityField.type('Helpful and friendly', { delay: 30 });
            logTest('Personality field filled', true);

            await takeScreenshot(page, 'test3-step4-form-filled');

            // Step 5: Click submit/create button
            console.log('Step 5: Clicking submit button...');
            const submitBtn = await page.$('button[type="submit"], button:has-text("Create"), button:has-text("Save")');

            if (submitBtn) {
              await submitBtn.click();
              await new Promise(resolve => setTimeout(resolve, 2000));
              logTest('Submit button clicked', true);

              // Step 6: Verify modal closes
              console.log('Step 6: Verifying modal closes...');
              const modalStillVisible = await page.$('[class*="modal"], [role="dialog"]').catch(() => null);
              logTest('Modal closed', !modalStillVisible);

              await takeScreenshot(page, 'test3-step6-after-submit');

              // Step 7: Check if new character appears
              console.log('Step 7: Checking if new character appears...');
              await new Promise(resolve => setTimeout(resolve, 1000));
              const pageContent = await page.content();
              const characterAppears = pageContent.includes('Browser Test Character');
              logTest('New character appears in list', characterAppears);

              await takeScreenshot(page, 'test3-step7-character-created');
            }
          }
        }
      } else {
        logTest('Character Creation Modal Test', false, 'New Character button not found');
      }

    } catch (error) {
      logTest('Character Creation Modal Test Complete', false, error.message);
    }

    // ========================================================================
    // TEST 4: Premium Paywall
    // ========================================================================
    console.log('\n' + '='.repeat(80));
    console.log('TEST 4: Premium Paywall');
    console.log('='.repeat(80) + '\n');

    try {
      // Step 1: Navigate to Black Mirror
      console.log('Step 1: Navigating to /black-mirror...');
      await page.goto(`${BASE_URL}/black-mirror`, { waitUntil: 'networkidle2' });
      await new Promise(resolve => setTimeout(resolve, 2000));
      await takeScreenshot(page, 'test4-step1-black-mirror');

      // Step 2: Check for premium gate
      console.log('Step 2: Checking for premium gate...');
      const premiumGate = await page.$('[class*="premium"], [class*="paywall"], button:has-text("Upgrade")').catch(() => null);
      const upgradeButton = await page.$('button:has-text("Upgrade"), button:has-text("Premium"), a:has-text("Upgrade")').catch(() => null);

      if (premiumGate || upgradeButton) {
        logTest('Premium gate appears for free users', true);

        // Step 3-4: Click upgrade button
        if (upgradeButton) {
          console.log('Step 3-4: Clicking "Upgrade to Premium" button...');
          await upgradeButton.click();
          await new Promise(resolve => setTimeout(resolve, 1500));
          logTest('Upgrade button clicked', true);

          // Step 5: Check for paywall modal
          console.log('Step 5: Checking for paywall modal...');
          const paywallModal = await page.$('[class*="modal"], [role="dialog"]').catch(() => null);
          logTest('Paywall modal opens', !!paywallModal);

          await takeScreenshot(page, 'test4-step5-paywall-modal');

          // Step 6: Check pricing
          console.log('Step 6: Checking pricing display...');
          const pageText = await page.evaluate(() => document.body.innerText);
          const has999Price = pageText.includes('9.99') || pageText.includes('$9') || pageText.includes('9,99');
          const has75Price = pageText.includes('75') || pageText.includes('$75');
          const has150Price = pageText.includes('150') || pageText.includes('$150');

          logTest('Monthly price ($9.99) displayed', has999Price);
          logTest('Yearly price ($75) displayed', has75Price);
          logTest('Lifetime price ($150) displayed', has150Price);

          await takeScreenshot(page, 'test4-step6-pricing');
        }
      } else {
        logTest('Premium access granted (premium user)', true, 'No paywall detected');
      }

    } catch (error) {
      logTest('Premium Paywall Test Complete', false, error.message);
    }

    // ========================================================================
    // TEST 5: Stripe Checkout Button
    // ========================================================================
    console.log('\n' + '='.repeat(80));
    console.log('TEST 5: Stripe Checkout Button');
    console.log('='.repeat(80) + '\n');

    try {
      // Check if modal is still open, if not try to open it again
      let paywallModal = await page.$('[class*="modal"], [role="dialog"]').catch(() => null);

      if (!paywallModal) {
        console.log('Reopening paywall modal...');
        const upgradeButton = await page.$('button:has-text("Upgrade"), button:has-text("Premium")').catch(() => null);
        if (upgradeButton) {
          await upgradeButton.click();
          await new Promise(resolve => setTimeout(resolve, 1500));
        }
      }

      // Step 1-2: Click Subscribe Monthly button
      console.log('Step 1-2: Looking for Subscribe Monthly button...');
      const subscribeButton = await page.$('button:has-text("Subscribe"), button:has-text("Monthly"), button:has-text("$9")').catch(() => null);

      if (subscribeButton) {
        logTest('Subscribe button found', true);

        // Monitor for redirect attempt
        let redirectAttempted = false;
        page.on('framenavigated', () => {
          redirectAttempted = true;
        });

        await takeScreenshot(page, 'test5-step1-before-click');

        await subscribeButton.click();
        await new Promise(resolve => setTimeout(resolve, 3000));

        logTest('Subscribe button clicked', true);
        logTest('Redirect attempted', redirectAttempted);

        await takeScreenshot(page, 'test5-step2-after-click');
      } else {
        logTest('Stripe Checkout Button Test', false, 'Subscribe button not found');
      }

    } catch (error) {
      logTest('Stripe Checkout Button Test Complete', false, error.message);
    }

    // ========================================================================
    // TEST 6: Error Handling
    // ========================================================================
    console.log('\n' + '='.repeat(80));
    console.log('TEST 6: Error Handling');
    console.log('='.repeat(80) + '\n');

    try {
      // Navigate to login page
      await page.goto(`${BASE_URL}/login`, { waitUntil: 'networkidle2' });
      await new Promise(resolve => setTimeout(resolve, 2000));

      // Step 1: Try logging in with wrong password
      console.log('Step 1: Attempting login with wrong password...');

      const emailInput = await page.$('input[type="email"], input[name="email"]');
      const passwordInput = await page.$('input[type="password"]');
      const submitButton = await page.$('button[type="submit"]');

      if (emailInput && passwordInput && submitButton) {
        await emailInput.click({ clickCount: 3 });
        await emailInput.type('test@example.com', { delay: 30 });

        await passwordInput.click({ clickCount: 3 });
        await passwordInput.type('wrongpassword123', { delay: 30 });

        await takeScreenshot(page, 'test6-step1-wrong-credentials');

        await submitButton.click();
        await new Promise(resolve => setTimeout(resolve, 3000));

        logTest('Wrong password login attempted', true);

        // Step 2: Verify error message appears
        console.log('Step 2: Checking for error message...');
        const errorMessage = await page.$('[class*="error"], [role="alert"], .alert-danger, [class*="Error"]').catch(() => null);
        const pageText = await page.evaluate(() => document.body.innerText.toLowerCase());
        const hasErrorText = pageText.includes('error') || pageText.includes('invalid') || pageText.includes('incorrect') || pageText.includes('wrong');

        logTest('Error message appears', !!(errorMessage || hasErrorText));

        await takeScreenshot(page, 'test6-step2-error-message');

        // Step 3: Check form doesn't crash
        console.log('Step 3: Verifying form is still functional...');
        const formStillExists = await page.$('form, input[type="email"]').catch(() => null);
        logTest('Form still functional after error', !!formStillExists);

        await takeScreenshot(page, 'test6-step3-form-state');
      }

    } catch (error) {
      logTest('Error Handling Test Complete', false, error.message);
    }

    // ========================================================================
    // TEST 7: Responsive Design
    // ========================================================================
    console.log('\n' + '='.repeat(80));
    console.log('TEST 7: Responsive Design');
    console.log('='.repeat(80) + '\n');

    try {
      // Re-login to test on different viewports
      await page.goto(`${BASE_URL}/login`, { waitUntil: 'networkidle2' });
      await new Promise(resolve => setTimeout(resolve, 1000));

      const emailInput = await page.$('input[type="email"], input[name="email"]');
      const passwordInput = await page.$('input[type="password"]');
      const submitButton = await page.$('button[type="submit"]');

      if (emailInput && passwordInput && submitButton) {
        await emailInput.click({ clickCount: 3 });
        await emailInput.type(TEST_EMAIL);
        await passwordInput.click({ clickCount: 3 });
        await passwordInput.type(TEST_PASSWORD);
        await Promise.all([
          page.waitForNavigation({ waitUntil: 'networkidle2', timeout: 10000 }).catch(() => {}),
          submitButton.click()
        ]);
        await new Promise(resolve => setTimeout(resolve, 2000));
      }

      const viewports = [
        { name: 'Desktop', width: 1920, height: 1080 },
        { name: 'Tablet', width: 768, height: 1024 },
        { name: 'Mobile', width: 375, height: 667 }
      ];

      for (const viewport of viewports) {
        console.log(`Testing ${viewport.name} viewport (${viewport.width}x${viewport.height})...`);

        await page.setViewport({ width: viewport.width, height: viewport.height });
        await new Promise(resolve => setTimeout(resolve, 1000));

        // Check for layout issues
        const layoutOk = await page.evaluate(() => {
          const body = document.body;
          const hasHorizontalScroll = body.scrollWidth > body.clientWidth;
          return !hasHorizontalScroll;
        });

        logTest(`${viewport.name} layout doesn't break`, layoutOk, `${viewport.width}x${viewport.height}`);

        await takeScreenshot(page, `test7-${viewport.name.toLowerCase()}-viewport`);
      }

    } catch (error) {
      logTest('Responsive Design Test Complete', false, error.message);
    }

    // ========================================================================
    // TEST 8: Console Errors Summary
    // ========================================================================
    console.log('\n' + '='.repeat(80));
    console.log('TEST 8: Console Errors Summary');
    console.log('='.repeat(80) + '\n');

    const hasConsoleErrors = testResults.consoleErrors.length > 0;
    const hasNetworkErrors = testResults.networkErrors.length > 0;

    logTest('No console errors', !hasConsoleErrors, `Found ${testResults.consoleErrors.length} console errors`);
    logTest('No network errors', !hasNetworkErrors, `Found ${testResults.networkErrors.length} network errors`);

  } catch (error) {
    console.error('\n❌ CRITICAL ERROR:', error);
    testResults.failed.push({ test: 'Overall Test Execution', details: error.message });
  } finally {
    await browser.close();
  }

  // ========================================================================
  // FINAL REPORT
  // ========================================================================
  console.log('\n\n');
  console.log('█'.repeat(80));
  console.log('█' + ' '.repeat(78) + '█');
  console.log('█' + ' '.repeat(25) + 'FINAL TEST REPORT' + ' '.repeat(36) + '█');
  console.log('█' + ' '.repeat(78) + '█');
  console.log('█'.repeat(80));
  console.log('\n');

  console.log(`✅ PASSED: ${testResults.passed.length}`);
  console.log(`❌ FAILED: ${testResults.failed.length}`);
  console.log(`⚠️  WARNINGS: ${testResults.warnings.length}`);
  console.log(`🔴 CONSOLE ERRORS: ${testResults.consoleErrors.length}`);
  console.log(`🔴 NETWORK ERRORS: ${testResults.networkErrors.length}`);

  console.log('\n' + '-'.repeat(80));
  console.log('PASSED TESTS:');
  console.log('-'.repeat(80));
  testResults.passed.forEach((result, i) => {
    console.log(`${i + 1}. ✅ ${result.test}`);
    if (result.details) console.log(`   ${result.details}`);
  });

  if (testResults.failed.length > 0) {
    console.log('\n' + '-'.repeat(80));
    console.log('FAILED TESTS:');
    console.log('-'.repeat(80));
    testResults.failed.forEach((result, i) => {
      console.log(`${i + 1}. ❌ ${result.test}`);
      console.log(`   ${result.details}`);
    });
  }

  if (testResults.consoleErrors.length > 0) {
    console.log('\n' + '-'.repeat(80));
    console.log('CONSOLE ERRORS:');
    console.log('-'.repeat(80));
    testResults.consoleErrors.slice(0, 10).forEach((error, i) => {
      console.log(`${i + 1}. ${error}`);
    });
    if (testResults.consoleErrors.length > 10) {
      console.log(`... and ${testResults.consoleErrors.length - 10} more`);
    }
  }

  if (testResults.networkErrors.length > 0) {
    console.log('\n' + '-'.repeat(80));
    console.log('NETWORK ERRORS:');
    console.log('-'.repeat(80));
    testResults.networkErrors.slice(0, 10).forEach((error, i) => {
      console.log(`${i + 1}. ${error.status} - ${error.url}`);
    });
    if (testResults.networkErrors.length > 10) {
      console.log(`... and ${testResults.networkErrors.length - 10} more`);
    }
  }

  console.log('\n' + '='.repeat(80));
  console.log(`📸 Screenshots saved in: ${screenshotsDir}/`);
  console.log('='.repeat(80));

  // Save report to file
  const reportPath = './test-report.json';
  fs.writeFileSync(reportPath, JSON.stringify(testResults, null, 2));
  console.log(`\n📄 Detailed report saved to: ${reportPath}`);

  // Exit with proper code
  process.exit(testResults.failed.length > 0 ? 1 : 0);
}

// Run tests
runTests().catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});
