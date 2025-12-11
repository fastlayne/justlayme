import puppeteer from 'puppeteer';
import fs from 'fs';

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
  networkErrors: [],
  performanceMetrics: []
};

// Helper functions
async function takeScreenshot(page, name) {
  const timestamp = Date.now();
  const filename = `${screenshotsDir}/${timestamp}-${name}.png`;
  await page.screenshot({ path: filename, fullPage: true });
  console.log(`📸 Screenshot: ${filename}`);
  return filename;
}

async function saveHTML(page, name) {
  const timestamp = Date.now();
  const filename = `${screenshotsDir}/${timestamp}-${name}.html`;
  const html = await page.content();
  fs.writeFileSync(filename, html);
  console.log(`📄 HTML saved: ${filename}`);
  return filename;
}

function logTest(testName, passed, details = '') {
  if (passed) {
    testResults.passed.push({ test: testName, details });
    console.log(`✅ PASS: ${testName}${details ? ' - ' + details : ''}`);
  } else {
    testResults.failed.push({ test: testName, details });
    console.log(`❌ FAIL: ${testName}${details ? ' - ' + details : ''}`);
  }
}

async function runTests() {
  console.log('\n🚀 JustLayMe Comprehensive Browser Testing\n');
  console.log('='.repeat(80));

  const browser = await puppeteer.launch({
    headless: true,
    args: [
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--disable-dev-shm-usage',
      '--disable-gpu',
      '--window-size=1920,1080'
    ]
  });

  try {
    const page = await browser.newPage();
    await page.setViewport({ width: 1920, height: 1080 });

    // Enable request interception to measure performance
    await page.setRequestInterception(true);
    const requestTimes = {};

    page.on('request', request => {
      requestTimes[request.url()] = Date.now();
      request.continue();
    });

    page.on('response', response => {
      const url = response.url();
      const status = response.status();
      const startTime = requestTimes[url];

      if (startTime) {
        const duration = Date.now() - startTime;
        if (duration > 3000) {
          testResults.performanceMetrics.push({ url, duration, slow: true });
        }
      }

      if (status >= 400) {
        testResults.networkErrors.push({ url, status });
        console.log(`🔴 ${status} Error: ${url}`);
      }
    });

    // Monitor console
    page.on('console', msg => {
      const type = msg.type();
      const text = msg.text();
      if (type === 'error') {
        testResults.consoleErrors.push(text);
        console.log(`🔴 Console Error: ${text}`);
      } else if (type === 'warning') {
        testResults.warnings.push(text);
      }
    });

    // ========================================================================
    // TEST 1: Login Flow
    // ========================================================================
    console.log('\n' + '='.repeat(80));
    console.log('TEST 1: Login Flow (Real User Journey)');
    console.log('='.repeat(80));

    try {
      const startTime = Date.now();
      console.log('\n🌐 Navigating to /login...');

      await page.goto(`${BASE_URL}/login`, {
        waitUntil: 'networkidle0',
        timeout: 30000
      });

      const loadTime = Date.now() - startTime;
      logTest('Login page loads', true, `${loadTime}ms`);
      testResults.performanceMetrics.push({ page: 'login', loadTime });

      // Wait for React to render
      await new Promise(resolve => setTimeout(resolve, 3000));

      await takeScreenshot(page, 'login-page-loaded');
      await saveHTML(page, 'login-page');

      // Get actual page structure
      const pageStructure = await page.evaluate(() => {
        const inputs = Array.from(document.querySelectorAll('input')).map(el => ({
          type: el.type,
          name: el.name,
          id: el.id,
          placeholder: el.placeholder,
          className: el.className
        }));

        const buttons = Array.from(document.querySelectorAll('button')).map(el => ({
          type: el.type,
          text: el.textContent?.trim(),
          className: el.className,
          id: el.id
        }));

        return { inputs, buttons, bodyText: document.body.innerText.substring(0, 500) };
      });

      console.log('\n📋 Page Structure:');
      console.log('Inputs:', JSON.stringify(pageStructure.inputs, null, 2));
      console.log('Buttons:', JSON.stringify(pageStructure.buttons, null, 2));
      console.log('Body preview:', pageStructure.bodyText);

      // Find email input
      let emailInput = await page.$('input[type="email"]');
      if (!emailInput) emailInput = await page.$('input[name="email"]');
      if (!emailInput) emailInput = await page.$('input[id*="email" i]');
      logTest('Email input exists', !!emailInput);

      // Find password input
      let passwordInput = await page.$('input[type="password"]');
      logTest('Password input exists', !!passwordInput);

      // Find submit button
      let submitButton = await page.$('button[type="submit"]');
      if (!submitButton) {
        const buttons = await page.$$('button');
        for (const btn of buttons) {
          const text = await page.evaluate(el => el.textContent, btn);
          if (text.toLowerCase().includes('sign') || text.toLowerCase().includes('login') || text.toLowerCase().includes('submit')) {
            submitButton = btn;
            break;
          }
        }
      }
      logTest('Submit button exists', !!submitButton);

      if (emailInput && passwordInput && submitButton) {
        console.log('\n📝 Filling login form...');

        await emailInput.click();
        await emailInput.type(TEST_EMAIL, { delay: 50 });
        logTest('Email entered', true);

        await passwordInput.click();
        await passwordInput.type(TEST_PASSWORD, { delay: 50 });
        logTest('Password entered', true);

        await takeScreenshot(page, 'login-form-filled');

        console.log('\n🔐 Submitting login...');
        await Promise.all([
          submitButton.click(),
          page.waitForNavigation({ waitUntil: 'networkidle0', timeout: 15000 }).catch(e => {
            console.log('Navigation wait timeout (may be expected)');
          })
        ]);

        await new Promise(resolve => setTimeout(resolve, 3000));

        const currentUrl = page.url();
        console.log(`📍 Current URL: ${currentUrl}`);

        const redirectedToChat = currentUrl.includes('/chat');
        logTest('Redirected to /chat', redirectedToChat, currentUrl);

        await takeScreenshot(page, 'after-login');

        // Check auth token
        const authToken = await page.evaluate(() => {
          const keys = Object.keys(localStorage);
          const authKeys = keys.filter(k => k.toLowerCase().includes('token') || k.toLowerCase().includes('auth'));
          return authKeys.map(k => ({ key: k, value: localStorage.getItem(k)?.substring(0, 50) }));
        });

        logTest('Auth token in localStorage', authToken.length > 0, JSON.stringify(authToken));

        // Check for logged-in indicators
        const userIndicators = await page.evaluate(() => {
          const logoutBtn = document.querySelector('button, a')?.textContent?.toLowerCase().includes('logout');
          const userProfile = !!document.querySelector('[class*="profile"], [class*="user-menu"], [class*="avatar"]');
          return { logoutBtn, userProfile };
        });

        logTest('User logged in', authToken.length > 0 || userIndicators.logoutBtn || userIndicators.userProfile);

      } else {
        logTest('Login Flow', false, 'Form elements not found');
      }

    } catch (error) {
      logTest('Login Flow', false, error.message);
    }

    // ========================================================================
    // TEST 2: Navigation & UI
    // ========================================================================
    console.log('\n' + '='.repeat(80));
    console.log('TEST 2: Navigation & UI Elements');
    console.log('='.repeat(80));

    try {
      // Get current page structure
      const uiElements = await page.evaluate(() => {
        return {
          sidebar: !!document.querySelector('aside, [class*="sidebar"], nav[class*="side"]'),
          buttons: Array.from(document.querySelectorAll('button')).map(b => b.textContent?.trim()).filter(Boolean),
          links: Array.from(document.querySelectorAll('a')).map(a => ({ text: a.textContent?.trim(), href: a.href })),
          headings: Array.from(document.querySelectorAll('h1, h2, h3')).map(h => h.textContent?.trim())
        };
      });

      console.log('\n📋 UI Elements found:');
      console.log('Sidebar:', uiElements.sidebar);
      console.log('Buttons:', uiElements.buttons);
      console.log('Links:', uiElements.links);
      console.log('Headings:', uiElements.headings);

      logTest('Sidebar visible', uiElements.sidebar);

      const hasNewCharButton = uiElements.buttons.some(b =>
        b?.toLowerCase().includes('new') ||
        b?.toLowerCase().includes('create') ||
        b?.toLowerCase().includes('character')
      );
      logTest('New Character button exists', hasNewCharButton);

      const hasChatLink = uiElements.links.some(l => l.href?.includes('/chat'));
      logTest('Chat link exists', hasChatLink);

      const hasBlackMirrorLink = uiElements.links.some(l =>
        l.href?.includes('black-mirror') || l.href?.includes('black')
      );
      logTest('Black Mirror link exists', hasBlackMirrorLink);

      await takeScreenshot(page, 'ui-elements');

    } catch (error) {
      logTest('Navigation & UI', false, error.message);
    }

    // ========================================================================
    // TEST 3: Character Creation
    // ========================================================================
    console.log('\n' + '='.repeat(80));
    console.log('TEST 3: Character Creation Modal');
    console.log('='.repeat(80));

    try {
      // Find and click new character button
      const newCharButton = await page.evaluateHandle(() => {
        const buttons = Array.from(document.querySelectorAll('button'));
        return buttons.find(b =>
          b.textContent?.toLowerCase().includes('new') &&
          b.textContent?.toLowerCase().includes('character')
        ) || buttons.find(b => b.textContent?.toLowerCase().includes('create'));
      });

      if (newCharButton.asElement()) {
        console.log('\n🆕 Clicking New Character button...');
        await newCharButton.asElement().click();
        await new Promise(resolve => setTimeout(resolve, 2000));

        logTest('New Character button clicked', true);
        await takeScreenshot(page, 'character-modal-opened');

        const modalOpen = await page.evaluate(() => {
          return !!document.querySelector('[role="dialog"], [class*="modal"], [class*="Modal"]');
        });

        logTest('Modal opened', modalOpen);

        if (modalOpen) {
          // Try to fill character form
          const formFilled = await page.evaluate(() => {
            const nameInput = document.querySelector('input[name*="name" i], input[placeholder*="name" i]');
            const bioInput = document.querySelector('textarea[name*="bio" i], textarea[placeholder*="bio" i]');

            if (nameInput) nameInput.value = 'Browser Test Character';
            if (bioInput) bioInput.value = 'Created via automated test';

            return { nameInput: !!nameInput, bioInput: !!bioInput };
          });

          logTest('Character form found', formFilled.nameInput && formFilled.bioInput);
          await takeScreenshot(page, 'character-form-filled');
        }
      } else {
        logTest('Character Creation', false, 'New Character button not found');
      }

    } catch (error) {
      logTest('Character Creation', false, error.message);
    }

    // ========================================================================
    // TEST 4: Black Mirror & Premium Features
    // ========================================================================
    console.log('\n' + '='.repeat(80));
    console.log('TEST 4: Black Mirror & Premium Features');
    console.log('='.repeat(80));

    try {
      console.log('\n🌑 Navigating to /black-mirror...');
      await page.goto(`${BASE_URL}/black-mirror`, {
        waitUntil: 'networkidle0',
        timeout: 30000
      });
      await new Promise(resolve => setTimeout(resolve, 3000));

      await takeScreenshot(page, 'black-mirror-page');
      await saveHTML(page, 'black-mirror-page');

      const premiumCheck = await page.evaluate(() => {
        const bodyText = document.body.innerText.toLowerCase();
        return {
          hasPremiumGate: bodyText.includes('premium') || bodyText.includes('upgrade'),
          hasPaywall: !!document.querySelector('[class*="paywall"], [class*="premium-gate"]'),
          prices: {
            monthly: bodyText.includes('9.99') || bodyText.includes('$9'),
            yearly: bodyText.includes('75') || bodyText.includes('$75'),
            lifetime: bodyText.includes('150') || bodyText.includes('$150')
          }
        };
      });

      console.log('\n💎 Premium check:', premiumCheck);

      if (premiumCheck.hasPremiumGate || premiumCheck.hasPaywall) {
        logTest('Premium gate detected', true);

        // Look for upgrade button
        const upgradeButton = await page.evaluateHandle(() => {
          const buttons = Array.from(document.querySelectorAll('button, a'));
          return buttons.find(b =>
            b.textContent?.toLowerCase().includes('upgrade') ||
            b.textContent?.toLowerCase().includes('premium')
          );
        });

        if (upgradeButton.asElement()) {
          await upgradeButton.asElement().click();
          await new Promise(resolve => setTimeout(resolve, 2000));
          await takeScreenshot(page, 'premium-modal');
          logTest('Premium modal opened', true);
        }

        logTest('Monthly price shown', premiumCheck.prices.monthly);
        logTest('Yearly price shown', premiumCheck.prices.yearly);
        logTest('Lifetime price shown', premiumCheck.prices.lifetime);
      } else {
        logTest('Premium access granted', true, 'No paywall detected (premium user)');
      }

    } catch (error) {
      logTest('Black Mirror & Premium', false, error.message);
    }

    // ========================================================================
    // TEST 5: Error Handling
    // ========================================================================
    console.log('\n' + '='.repeat(80));
    console.log('TEST 5: Error Handling');
    console.log('='.repeat(80));

    try {
      console.log('\n🚫 Testing wrong credentials...');
      await page.goto(`${BASE_URL}/login`, { waitUntil: 'networkidle0' });
      await new Promise(resolve => setTimeout(resolve, 2000));

      const emailInput = await page.$('input[type="email"]');
      const passwordInput = await page.$('input[type="password"]');
      const submitButton = await page.$('button[type="submit"]');

      if (emailInput && passwordInput && submitButton) {
        await emailInput.click({ clickCount: 3 });
        await emailInput.type('wrong@example.com');
        await passwordInput.click({ clickCount: 3 });
        await passwordInput.type('wrongpassword123');

        await takeScreenshot(page, 'wrong-credentials');
        await submitButton.click();
        await new Promise(resolve => setTimeout(resolve, 3000));

        const errorCheck = await page.evaluate(() => {
          const bodyText = document.body.innerText.toLowerCase();
          return {
            hasError: bodyText.includes('error') ||
                     bodyText.includes('invalid') ||
                     bodyText.includes('incorrect') ||
                     bodyText.includes('wrong'),
            errorElements: !!document.querySelector('[class*="error"], [role="alert"]')
          };
        });

        logTest('Error message displayed', errorCheck.hasError || errorCheck.errorElements);
        await takeScreenshot(page, 'error-displayed');

        const formStillWorks = await page.$('input[type="email"]');
        logTest('Form still functional', !!formStillWorks);
      }

    } catch (error) {
      logTest('Error Handling', false, error.message);
    }

    // ========================================================================
    // TEST 6: Responsive Design
    // ========================================================================
    console.log('\n' + '='.repeat(80));
    console.log('TEST 6: Responsive Design');
    console.log('='.repeat(80));

    const viewports = [
      { name: 'Desktop', width: 1920, height: 1080 },
      { name: 'Laptop', width: 1366, height: 768 },
      { name: 'Tablet', width: 768, height: 1024 },
      { name: 'Mobile', width: 375, height: 667 }
    ];

    for (const viewport of viewports) {
      try {
        console.log(`\n📱 Testing ${viewport.name} (${viewport.width}x${viewport.height})...`);
        await page.setViewport({ width: viewport.width, height: viewport.height });
        await new Promise(resolve => setTimeout(resolve, 1000));

        const layoutCheck = await page.evaluate(() => {
          return {
            horizontalScroll: document.body.scrollWidth > window.innerWidth,
            hasContent: document.body.innerText.length > 0,
            visibleElements: document.querySelectorAll('*:not([style*="display: none"])').length
          };
        });

        logTest(`${viewport.name} - No horizontal scroll`, !layoutCheck.horizontalScroll);
        logTest(`${viewport.name} - Content visible`, layoutCheck.hasContent);

        await takeScreenshot(page, `responsive-${viewport.name.toLowerCase()}`);

      } catch (error) {
        logTest(`${viewport.name} viewport`, false, error.message);
      }
    }

    // ========================================================================
    // TEST 7: Performance Metrics
    // ========================================================================
    console.log('\n' + '='.repeat(80));
    console.log('TEST 7: Performance Analysis');
    console.log('='.repeat(80));

    const slowRequests = testResults.performanceMetrics.filter(m => m.slow);
    logTest('No slow requests (>3s)', slowRequests.length === 0,
      slowRequests.length > 0 ? `${slowRequests.length} slow requests` : '');

    const metrics = await page.evaluate(() => {
      const perfData = performance.getEntriesByType('navigation')[0];
      return perfData ? {
        domContentLoaded: Math.round(perfData.domContentLoadedEventEnd - perfData.fetchStart),
        loadComplete: Math.round(perfData.loadEventEnd - perfData.fetchStart),
        domInteractive: Math.round(perfData.domInteractive - perfData.fetchStart)
      } : null;
    });

    if (metrics) {
      console.log('\n⚡ Performance metrics:');
      console.log(`  - DOM Content Loaded: ${metrics.domContentLoaded}ms`);
      console.log(`  - Load Complete: ${metrics.loadComplete}ms`);
      console.log(`  - DOM Interactive: ${metrics.domInteractive}ms`);

      logTest('Fast DOM load (<3s)', metrics.domContentLoaded < 3000);
      logTest('Fast page load (<5s)', metrics.loadComplete < 5000);
    }

  } catch (error) {
    console.error('\n❌ CRITICAL ERROR:', error);
    testResults.failed.push({ test: 'Test Execution', details: error.message });
  } finally {
    await browser.close();
  }

  // ========================================================================
  // FINAL REPORT
  // ========================================================================
  console.log('\n\n');
  console.log('█'.repeat(80));
  console.log('█' + ' '.repeat(20) + 'JUSTLAYME BROWSER TEST REPORT' + ' '.repeat(29) + '█');
  console.log('█'.repeat(80));

  const passRate = Math.round((testResults.passed.length / (testResults.passed.length + testResults.failed.length)) * 100);

  console.log('\n📊 SUMMARY:');
  console.log(`  ✅ Passed: ${testResults.passed.length}`);
  console.log(`  ❌ Failed: ${testResults.failed.length}`);
  console.log(`  📈 Pass Rate: ${passRate}%`);
  console.log(`  ⚠️  Warnings: ${testResults.warnings.length}`);
  console.log(`  🔴 Console Errors: ${testResults.consoleErrors.length}`);
  console.log(`  🔴 Network Errors: ${testResults.networkErrors.length}`);

  console.log('\n' + '-'.repeat(80));
  console.log('✅ PASSED TESTS:');
  console.log('-'.repeat(80));
  testResults.passed.forEach((result, i) => {
    console.log(`${i + 1}. ${result.test}${result.details ? ' - ' + result.details : ''}`);
  });

  if (testResults.failed.length > 0) {
    console.log('\n' + '-'.repeat(80));
    console.log('❌ FAILED TESTS:');
    console.log('-'.repeat(80));
    testResults.failed.forEach((result, i) => {
      console.log(`${i + 1}. ${result.test}`);
      if (result.details) console.log(`   → ${result.details}`);
    });
  }

  if (testResults.consoleErrors.length > 0) {
    console.log('\n' + '-'.repeat(80));
    console.log('🔴 CONSOLE ERRORS:');
    console.log('-'.repeat(80));
    const uniqueErrors = [...new Set(testResults.consoleErrors)];
    uniqueErrors.slice(0, 10).forEach((error, i) => {
      console.log(`${i + 1}. ${error.substring(0, 100)}`);
    });
    if (uniqueErrors.length > 10) {
      console.log(`... and ${uniqueErrors.length - 10} more unique errors`);
    }
  }

  if (testResults.networkErrors.length > 0) {
    console.log('\n' + '-'.repeat(80));
    console.log('🔴 NETWORK ERRORS:');
    console.log('-'.repeat(80));
    const uniqueNetworkErrors = Array.from(new Set(testResults.networkErrors.map(e => JSON.stringify(e))))
      .map(e => JSON.parse(e));
    uniqueNetworkErrors.slice(0, 10).forEach((error, i) => {
      console.log(`${i + 1}. ${error.status} - ${error.url}`);
    });
    if (uniqueNetworkErrors.length > 10) {
      console.log(`... and ${uniqueNetworkErrors.length - 10} more errors`);
    }
  }

  console.log('\n' + '='.repeat(80));
  console.log(`📸 Screenshots saved in: ${screenshotsDir}/`);
  console.log('='.repeat(80));

  // Save detailed report
  const reportPath = './test-report-detailed.json';
  fs.writeFileSync(reportPath, JSON.stringify(testResults, null, 2));
  console.log(`\n📄 Detailed JSON report: ${reportPath}\n`);

  process.exit(testResults.failed.length > 0 ? 1 : 0);
}

runTests().catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});
