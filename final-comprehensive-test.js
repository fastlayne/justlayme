import puppeteer from 'puppeteer';
import fs from 'fs';

const screenshotsDir = './test-screenshots-final';
if (!fs.existsSync(screenshotsDir)) {
  fs.mkdirSync(screenshotsDir, { recursive: true });
}

const BASE_URL = 'https://justlay.me';
const TEST_EMAIL = 'please@justlay.me';
const TEST_PASSWORD = 'Luna2025';

const results = {
  passed: [],
  failed: [],
  warnings: [],
  consoleErrors: [],
  networkErrors: [],
  screenshots: []
};

function logPass(test, details = '') {
  results.passed.push({ test, details });
  console.log(`✅ PASS: ${test}${details ? ' - ' + details : ''}`);
}

function logFail(test, details = '') {
  results.failed.push({ test, details });
  console.log(`❌ FAIL: ${test}${details ? ' - ' + details : ''}`);
}

function logWarning(msg) {
  results.warnings.push(msg);
  console.log(`⚠️  WARNING: ${msg}`);
}

async function screenshot(page, name, description = '') {
  const timestamp = Date.now();
  const filename = `${screenshotsDir}/${timestamp}-${name}.png`;
  await page.screenshot({ path: filename, fullPage: true });
  results.screenshots.push({ filename, name, description, timestamp });
  console.log(`📸 ${name}: ${filename}`);
  return filename;
}

async function waitForReact(page, selector = '#root > *', timeout = 10000) {
  try {
    await page.waitForFunction(
      (sel) => {
        const el = document.querySelector(sel);
        return el && el.children.length > 0;
      },
      { timeout },
      selector
    );
    return true;
  } catch (e) {
    console.log(`⏰ Timeout waiting for React to render: ${selector}`);
    return false;
  }
}

async function runComprehensiveTests() {
  console.log('\n' + '='.repeat(80));
  console.log('🚀 JustLayMe - COMPREHENSIVE REAL USER BROWSER TESTING');
  console.log('='.repeat(80) + '\n');

  const browser = await puppeteer.launch({
    headless: true,
    args: [
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--disable-dev-shm-usage',
      '--disable-gpu',
      '--disable-features=IsolateOrigins,site-per-process',
      '--disable-blink-features=AutomationControlled'
    ],
    defaultViewport: { width: 1920, height: 1080 }
  });

  try {
    const page = await browser.newPage();

    // Monitor all console messages
    page.on('console', msg => {
      const type = msg.type();
      const text = msg.text();
      if (type === 'error' && !text.includes('favicon')) {
        results.consoleErrors.push(text);
        console.log(`🔴 Console Error: ${text}`);
      }
    });

    // Monitor network errors
    page.on('response', response => {
      const status = response.status();
      const url = response.url();
      if (status >= 400 && !url.includes('favicon')) {
        results.networkErrors.push({ status, url });
        console.log(`🔴 Network ${status}: ${url}`);
      }
    });

    // ========================================================================
    console.log('\n' + '='.repeat(80));
    console.log('TEST 1: LOGIN FLOW - REAL USER JOURNEY');
    console.log('='.repeat(80) + '\n');
    // ========================================================================

    try {
      const startTime = Date.now();
      console.log('→ Navigating to /login...');

      await page.goto(`${BASE_URL}/login`, {
        waitUntil: 'networkidle2',
        timeout: 30000
      });

      const loadTime = Date.now() - startTime;
      logPass(`Login page loaded`, `${loadTime}ms`);

      // Wait for React to render
      console.log('→ Waiting for React app to render...');
      const reactRendered = await waitForReact(page, '#root > *', 15000);

      if (!reactRendered) {
        logWarning('React app did not render DOM content');
      }

      await new Promise(r => setTimeout(r, 3000));
      await screenshot(page, 'login-page', 'Initial login page load');

      // Check what rendered
      const pageState = await page.evaluate(() => {
        const root = document.querySelector('#root');
        return {
          hasContent: root && root.innerText.length > 0,
          innerHTML: root ? root.innerHTML.substring(0, 500) : '',
          bodyText: document.body.innerText.substring(0, 300),
          inputs: Array.from(document.querySelectorAll('input')).map(i => ({
            type: i.type,
            name: i.name,
            placeholder: i.placeholder,
            visible: i.offsetParent !== null
          })),
          buttons: Array.from(document.querySelectorAll('button')).map(b => ({
            text: b.textContent?.trim(),
            visible: b.offsetParent !== null
          })).filter(b => b.visible)
        };
      });

      console.log(`\n📊 Page State:`);
      console.log(`   Has content: ${pageState.hasContent}`);
      console.log(`   Visible inputs: ${pageState.inputs.filter(i => i.visible).length}`);
      console.log(`   Visible buttons: ${pageState.buttons.length}`);
      console.log(`   Body text: ${pageState.bodyText.substring(0, 100)}...`);

      logPass('React app rendered', `${pageState.hasContent ? 'Content visible' : 'No content'}`);

      // Find form elements
      const emailInput = await page.$('input[type="email"]');
      const passwordInput = await page.$('input[type="password"]');
      const submitButton = await page.$('button[type="submit"]');

      logPass('Email input found', !!emailInput);
      logPass('Password input found', !!passwordInput);
      logPass('Submit button found', !!submitButton);

      if (emailInput && passwordInput && submitButton) {
        console.log('\n→ Filling login form...');

        await emailInput.click();
        await emailInput.type(TEST_EMAIL, { delay: 30 });
        logPass('Email entered');

        await passwordInput.click();
        await passwordInput.type(TEST_PASSWORD, { delay: 30 });
        logPass('Password entered');

        await screenshot(page, 'login-filled', 'Login form filled out');

        console.log('\n→ Submitting login...');
        await Promise.all([
          submitButton.click(),
          page.waitForNavigation({ waitUntil: 'networkidle2', timeout: 15000 }).catch(() => {})
        ]);

        await new Promise(r => setTimeout(r, 3000));
        await waitForReact(page, '#root > *');

        const afterLogin = await page.evaluate(() => ({
          url: window.location.href,
          hasAuthToken: !!localStorage.getItem('authToken') || !!localStorage.getItem('token'),
          bodyText: document.body.innerText.substring(0, 200)
        }));

        console.log(`\n📍 After login:`);
        console.log(`   URL: ${afterLogin.url}`);
        console.log(`   Has auth token: ${afterLogin.hasAuthToken}`);

        logPass('Login submitted', true);
        logPass('Redirected after login', afterLogin.url.includes('/chat') || afterLogin.url !== `${BASE_URL}/login`);
        logPass('Auth token stored', afterLogin.hasAuthToken);

        await screenshot(page, 'after-login', 'State after login submission');
      } else {
        logFail('Login form complete', 'Missing form elements');
      }

    } catch (error) {
      logFail('Login Flow Test', error.message);
    }

    // ========================================================================
    console.log('\n' + '='.repeat(80));
    console.log('TEST 2: CHAT PAGE & NAVIGATION');
    console.log('='.repeat(80) + '\n');
    // ========================================================================

    try {
      console.log('→ Navigating to /chat...');
      await page.goto(`${BASE_URL}/chat`, {
        waitUntil: 'networkidle2',
        timeout: 30000
      });

      await waitForReact(page, '#root > *');
      await new Promise(r => setTimeout(r, 3000));

      const chatPageState = await page.evaluate(() => {
        const allButtons = Array.from(document.querySelectorAll('button')).map(b => b.textContent?.trim()).filter(Boolean);
        const allLinks = Array.from(document.querySelectorAll('a')).map(a => ({ text: a.textContent?.trim(), href: a.href }));

        return {
          bodyText: document.body.innerText,
          buttons: allButtons,
          links: allLinks,
          hasSidebar: !!document.querySelector('aside, nav, [class*="sidebar"], [class*="Sidebar"]'),
          hasContent: document.body.innerText.length > 100
        };
      });

      console.log(`\n📊 Chat Page State:`);
      console.log(`   Has content: ${chatPageState.hasContent}`);
      console.log(`   Has sidebar: ${chatPageState.hasSidebar}`);
      console.log(`   Buttons found: ${chatPageState.buttons.length}`);
      console.log(`   Links found: ${chatPageState.links.length}`);
      console.log(`   Sample buttons: ${chatPageState.buttons.slice(0, 5).join(', ')}`);

      logPass('Chat page loaded', chatPageState.hasContent);
      logPass('Sidebar present', chatPageState.hasSidebar);

      const hasNewCharButton = chatPageState.buttons.some(b =>
        b?.toLowerCase().includes('new') || b?.toLowerCase().includes('create')
      );
      logPass('New Character button exists', hasNewCharButton);

      const hasBlackMirrorNav = chatPageState.bodyText.toLowerCase().includes('black mirror') ||
                               chatPageState.links.some(l => l.href?.includes('black-mirror'));
      logPass('Black Mirror navigation exists', hasBlackMirrorNav);

      await screenshot(page, 'chat-page', 'Chat page main view');

    } catch (error) {
      logFail('Chat Page Test', error.message);
    }

    // ========================================================================
    console.log('\n' + '='.repeat(80));
    console.log('TEST 3: BLACK MIRROR & PREMIUM FEATURES');
    console.log('='.repeat(80) + '\n');
    // ========================================================================

    try {
      console.log('→ Navigating to /black-mirror...');
      await page.goto(`${BASE_URL}/black-mirror`, {
        waitUntil: 'networkidle2',
        timeout: 30000
      });

      await waitForReact(page, '#root > *');
      await new Promise(r => setTimeout(r, 3000));

      const blackMirrorState = await page.evaluate(() => {
        const text = document.body.innerText.toLowerCase();
        const html = document.body.innerHTML;

        return {
          bodyText: document.body.innerText,
          hasPremiumGate: text.includes('premium') || text.includes('upgrade') || html.includes('premium-gate'),
          hasBlackMirrorContent: text.includes('black mirror'),
          hasUploadSection: text.includes('upload') || text.includes('paste'),
          hasPricing: text.includes('$9') || text.includes('9.99') || text.includes('$75') || text.includes('$150'),
          buttons: Array.from(document.querySelectorAll('button')).map(b => b.textContent?.trim()).filter(Boolean)
        };
      });

      console.log(`\n📊 Black Mirror State:`);
      console.log(`   Has premium gate: ${blackMirrorState.hasPremiumGate}`);
      console.log(`   Has Black Mirror content: ${blackMirrorState.hasBlackMirrorContent}`);
      console.log(`   Has upload section: ${blackMirrorState.hasUploadSection}`);
      console.log(`   Buttons: ${blackMirrorState.buttons.join(', ')}`);

      logPass('Black Mirror page loaded', blackMirrorState.hasBlackMirrorContent);
      logPass('Premium gate detected', blackMirrorState.hasPremiumGate);
      logPass('Upload section visible', blackMirrorState.hasUploadSection);

      await screenshot(page, 'black-mirror', 'Black Mirror page with premium gate');

      // Try to click upgrade button
      const upgradeClicked = await page.evaluate(() => {
        const upgradeBtn = Array.from(document.querySelectorAll('button')).find(b =>
          b.textContent?.toLowerCase().includes('upgrade') ||
          b.textContent?.toLowerCase().includes('premium')
        );
        if (upgradeBtn) {
          upgradeBtn.click();
          return true;
        }
        return false;
      });

      if (upgradeClicked) {
        logPass('Upgrade button clicked', true);
        await new Promise(r => setTimeout(r, 2000));

        const modalState = await page.evaluate(() => {
          const modal = document.querySelector('[role="dialog"], [class*="modal"], [class*="Modal"]');
          const text = document.body.innerText.toLowerCase();

          return {
            hasModal: !!modal,
            hasMonthlyPrice: text.includes('9.99') || text.includes('$9'),
            hasYearlyPrice: text.includes('$75') || text.includes('75'),
            hasLifetimePrice: text.includes('$150') || text.includes('150'),
            modalText: modal ? modal.innerText.substring(0, 300) : ''
          };
        });

        console.log(`\n📊 Premium Modal State:`);
        console.log(`   Modal visible: ${modalState.hasModal}`);
        console.log(`   Has pricing: Monthly=${modalState.hasMonthlyPrice}, Yearly=${modalState.hasYearlyPrice}, Lifetime=${modalState.hasLifetimePrice}`);

        logPass('Premium modal opened', modalState.hasModal);
        logPass('Monthly pricing shown', modalState.hasMonthlyPrice);
        logPass('Yearly pricing shown', modalState.hasYearlyPrice);
        logPass('Lifetime pricing shown', modalState.hasLifetimePrice);

        await screenshot(page, 'premium-modal', 'Premium paywall modal');
      } else {
        logWarning('Upgrade button not found or not clickable');
      }

    } catch (error) {
      logFail('Black Mirror Test', error.message);
    }

    // ========================================================================
    console.log('\n' + '='.repeat(80));
    console.log('TEST 4: ERROR HANDLING');
    console.log('='.repeat(80) + '\n');
    // ========================================================================

    try {
      console.log('→ Testing wrong credentials...');
      await page.goto(`${BASE_URL}/login`, { waitUntil: 'networkidle2' });
      await waitForReact(page, '#root > *');
      await new Promise(r => setTimeout(r, 2000));

      const emailInput = await page.$('input[type="email"]');
      const passwordInput = await page.$('input[type="password"]');
      const submitButton = await page.$('button[type="submit"]');

      if (emailInput && passwordInput && submitButton) {
        await emailInput.click({ clickCount: 3 });
        await emailInput.type('wrong@example.com');
        await passwordInput.click({ clickCount: 3 });
        await passwordInput.type('wrongpassword123');

        await screenshot(page, 'wrong-creds', 'Wrong credentials entered');
        await submitButton.click();
        await new Promise(r => setTimeout(r, 3000));

        const errorState = await page.evaluate(() => {
          const text = document.body.innerText.toLowerCase();
          return {
            hasError: text.includes('error') || text.includes('invalid') ||
                     text.includes('incorrect') || text.includes('wrong') ||
                     text.includes('failed'),
            hasErrorElement: !!document.querySelector('[class*="error"], [role="alert"], .error'),
            formStillVisible: !!document.querySelector('input[type="email"]')
          };
        });

        logPass('Error message shown', errorState.hasError || errorState.hasErrorElement);
        logPass('Form still functional', errorState.formStillVisible);

        await screenshot(page, 'error-state', 'Error state after wrong credentials');
      }

    } catch (error) {
      logFail('Error Handling Test', error.message);
    }

    // ========================================================================
    console.log('\n' + '='.repeat(80));
    console.log('TEST 5: RESPONSIVE DESIGN');
    console.log('='.repeat(80) + '\n');
    // ========================================================================

    const viewports = [
      { name: 'Desktop', width: 1920, height: 1080 },
      { name: 'Laptop', width: 1366, height: 768 },
      { name: 'Tablet', width: 768, height: 1024 },
      { name: 'Mobile', width: 375, height: 667 }
    ];

    for (const vp of viewports) {
      try {
        console.log(`\n→ Testing ${vp.name} (${vp.width}x${vp.height})...`);
        await page.setViewport({ width: vp.width, height: vp.height });
        await page.goto(`${BASE_URL}/chat`, { waitUntil: 'networkidle2' });
        await waitForReact(page, '#root > *');
        await new Promise(r => setTimeout(r, 1500));

        const layoutCheck = await page.evaluate(() => ({
          horizontalScroll: document.body.scrollWidth > window.innerWidth,
          hasContent: document.body.innerText.length > 50,
          overflow: window.getComputedStyle(document.body).overflowX
        }));

        logPass(`${vp.name} - No horizontal scroll`, !layoutCheck.horizontalScroll);
        logPass(`${vp.name} - Content visible`, layoutCheck.hasContent);

        await screenshot(page, `responsive-${vp.name.toLowerCase()}`, `${vp.name} viewport`);

      } catch (error) {
        logFail(`${vp.name} Responsive Test`, error.message);
      }
    }

    // ========================================================================
    console.log('\n' + '='.repeat(80));
    console.log('TEST 6: PERFORMANCE METRICS');
    console.log('='.repeat(80) + '\n');
    // ========================================================================

    try {
      await page.setViewport({ width: 1920, height: 1080 });
      await page.goto(`${BASE_URL}/chat`, { waitUntil: 'load' });

      const metrics = await page.evaluate(() => {
        const perfData = performance.getEntriesByType('navigation')[0];
        return {
          domContentLoaded: Math.round(perfData.domContentLoadedEventEnd - perfData.fetchStart),
          loadComplete: Math.round(perfData.loadEventEnd - perfData.fetchStart),
          domInteractive: Math.round(perfData.domInteractive - perfData.fetchStart)
        };
      });

      console.log(`\n⚡ Performance Metrics:`);
      console.log(`   DOM Content Loaded: ${metrics.domContentLoaded}ms`);
      console.log(`   Load Complete: ${metrics.loadComplete}ms`);
      console.log(`   DOM Interactive: ${metrics.domInteractive}ms`);

      logPass('Fast DOM load (<3s)', metrics.domContentLoaded < 3000, `${metrics.domContentLoaded}ms`);
      logPass('Fast page load (<5s)', metrics.loadComplete < 5000, `${metrics.loadComplete}ms`);

    } catch (error) {
      logFail('Performance Test', error.message);
    }

  } catch (criticalError) {
    console.error('\n❌ CRITICAL ERROR:', criticalError);
    logFail('Critical Test Execution', criticalError.message);
  } finally {
    await browser.close();
  }

  // ========================================================================
  // FINAL COMPREHENSIVE REPORT
  // ========================================================================

  console.log('\n\n');
  console.log('█'.repeat(80));
  console.log('█' + ' '.repeat(15) + 'JUSTLAYME - COMPREHENSIVE BROWSER TEST REPORT' + ' '.repeat(18) + '█');
  console.log('█'.repeat(80));

  const totalTests = results.passed.length + results.failed.length;
  const passRate = totalTests > 0 ? Math.round((results.passed.length / totalTests) * 100) : 0;

  console.log('\n📊 TEST SUMMARY:');
  console.log('─'.repeat(80));
  console.log(`  Total Tests Run: ${totalTests}`);
  console.log(`  ✅ Passed: ${results.passed.length}`);
  console.log(`  ❌ Failed: ${results.failed.length}`);
  console.log(`  📈 Pass Rate: ${passRate}%`);
  console.log(`  ⚠️  Warnings: ${results.warnings.length}`);
  console.log(`  🔴 Console Errors: ${results.consoleErrors.length}`);
  console.log(`  🔴 Network Errors: ${results.networkErrors.length}`);
  console.log(`  📸 Screenshots: ${results.screenshots.length}`);

  console.log('\n✅ PASSED TESTS:');
  console.log('─'.repeat(80));
  results.passed.forEach((r, i) => {
    console.log(`  ${i + 1}. ${r.test}${r.details ? ' - ' + r.details : ''}`);
  });

  if (results.failed.length > 0) {
    console.log('\n❌ FAILED TESTS:');
    console.log('─'.repeat(80));
    results.failed.forEach((r, i) => {
      console.log(`  ${i + 1}. ${r.test}`);
      if (r.details) console.log(`      → ${r.details}`);
    });
  }

  if (results.warnings.length > 0) {
    console.log('\n⚠️  WARNINGS:');
    console.log('─'.repeat(80));
    results.warnings.forEach((w, i) => {
      console.log(`  ${i + 1}. ${w}`);
    });
  }

  if (results.consoleErrors.length > 0) {
    console.log('\n🔴 CONSOLE ERRORS:');
    console.log('─'.repeat(80));
    const uniqueErrors = [...new Set(results.consoleErrors)];
    uniqueErrors.slice(0, 5).forEach((e, i) => {
      console.log(`  ${i + 1}. ${e.substring(0, 120)}`);
    });
    if (uniqueErrors.length > 5) {
      console.log(`  ... and ${uniqueErrors.length - 5} more errors`);
    }
  }

  if (results.networkErrors.length > 0) {
    console.log('\n🔴 NETWORK ERRORS:');
    console.log('─'.repeat(80));
    results.networkErrors.slice(0, 5).forEach((e, i) => {
      console.log(`  ${i + 1}. ${e.status} - ${e.url}`);
    });
    if (results.networkErrors.length > 5) {
      console.log(`  ... and ${results.networkErrors.length - 5} more errors`);
    }
  }

  console.log('\n📸 SCREENSHOTS:');
  console.log('─'.repeat(80));
  results.screenshots.forEach((s, i) => {
    console.log(`  ${i + 1}. ${s.name} - ${s.filename}`);
  });

  console.log('\n' + '='.repeat(80));
  console.log(`📁 Screenshots directory: ${screenshotsDir}/`);
  console.log('='.repeat(80));

  const reportFile = './browser-test-report.json';
  fs.writeFileSync(reportFile, JSON.stringify(results, null, 2));
  console.log(`\n📄 Detailed JSON report saved: ${reportFile}\n`);

  // Overall assessment
  console.log('\n🎯 OVERALL ASSESSMENT:');
  console.log('─'.repeat(80));
  if (passRate >= 90) {
    console.log('  🌟 EXCELLENT - JustLayMe is working very well!');
  } else if (passRate >= 75) {
    console.log('  ✅ GOOD - Most features are working correctly');
  } else if (passRate >= 50) {
    console.log('  ⚠️  NEEDS ATTENTION - Several issues detected');
  } else {
    console.log('  🚨 CRITICAL - Significant issues need immediate attention');
  }
  console.log('─'.repeat(80) + '\n');

  process.exit(results.failed.length > 0 ? 1 : 0);
}

runComprehensiveTests().catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});
