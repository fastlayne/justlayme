import puppeteer from 'puppeteer';
import fs from 'fs';

const screenshotsDir = './test-screenshots-complete';
if (!fs.existsSync(screenshotsDir)) {
  fs.mkdirSync(screenshotsDir, { recursive: true });
}

const BASE_URL = 'https://justlay.me';

console.log('\n' + '='.repeat(80));
console.log('🧪 JUSTLAYME - COMPLETE REAL USER FLOW TEST');
console.log('='.repeat(80) + '\n');

(async () => {
  const browser = await puppeteer.launch({
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage']
  });

  const page = await browser.newPage();
  await page.setViewport({ width: 1920, height: 1080 });

  // Monitor console
  page.on('console', msg => {
    if (msg.type() === 'error') {
      console.log(`🔴 Console Error: ${msg.text()}`);
    }
  });

  try {
    // Test 1: Homepage
    console.log('\n📍 TEST 1: Homepage');
    console.log('-'.repeat(80));

    await page.goto(BASE_URL, { waitUntil: 'networkidle2', timeout: 30000 });
    await new Promise(r => setTimeout(r, 3000));

    const homepageState = await page.evaluate(() => ({
      url: window.location.href,
      title: document.title,
      bodyText: document.body.innerText.substring(0, 500),
      hasContent: document.body.innerText.length > 50,
      rootHTML: document.querySelector('#root')?.innerHTML?.substring(0, 500) || 'NO ROOT',
      buttons: Array.from(document.querySelectorAll('button')).map(b => b.textContent?.trim()),
      links: Array.from(document.querySelectorAll('a')).map(a => ({ text: a.textContent?.trim(), href: a.href }))
    }));

    console.log(`✓ URL: ${homepageState.url}`);
    console.log(`✓ Title: ${homepageState.title}`);
    console.log(`✓ Has content: ${homepageState.hasContent}`);
    console.log(`✓ Buttons: ${homepageState.buttons.slice(0, 5).join(', ')}`);
    console.log(`✓ Body preview: ${homepageState.bodyText.substring(0, 150)}...`);

    await page.screenshot({ path: `${screenshotsDir}/01-homepage.png`, fullPage: true });
    console.log(`📸 Screenshot: ${screenshotsDir}/01-homepage.png`);

    // Test 2: Login Page
    console.log('\n📍 TEST 2: Login Page');
    console.log('-'.repeat(80));

    await page.goto(`${BASE_URL}/login`, { waitUntil: 'networkidle2' });
    await new Promise(r => setTimeout(r, 3000));

    const loginState = await page.evaluate(() => ({
      url: window.location.href,
      bodyText: document.body.innerText,
      hasLoginForm: !!document.querySelector('form'),
      inputs: Array.from(document.querySelectorAll('input')).map(i => ({
        type: i.type,
        name: i.name,
        placeholder: i.placeholder
      })),
      buttons: Array.from(document.querySelectorAll('button')).map(b => b.textContent?.trim()),
      rootHTML: document.querySelector('#root')?.innerHTML || 'NO ROOT'
    }));

    console.log(`✓ URL: ${loginState.url}`);
    console.log(`✓ Has form: ${loginState.hasLoginForm}`);
    console.log(`✓ Inputs: ${JSON.stringify(loginState.inputs)}`);
    console.log(`✓ Buttons: ${loginState.buttons.join(', ')}`);
    console.log(`✓ Body text length: ${loginState.bodyText.length}`);
    console.log(`✓ Root HTML preview: ${loginState.rootHTML.substring(0, 200)}`);

    await page.screenshot({ path: `${screenshotsDir}/02-login.png`, fullPage: true });
    fs.writeFileSync(`${screenshotsDir}/02-login.html`, await page.content());
    console.log(`📸 Screenshot: ${screenshotsDir}/02-login.png`);

    // Test 3: Chat Page (may redirect if not authenticated)
    console.log('\n📍 TEST 3: Chat Page');
    console.log('-'.repeat(80));

    await page.goto(`${BASE_URL}/chat`, { waitUntil: 'networkidle2', timeout: 30000 });
    await new Promise(r => setTimeout(r, 3000));

    const chatState = await page.evaluate(() => ({
      url: window.location.href,
      bodyText: document.body.innerText.substring(0, 300),
      hasContent: document.body.innerText.length > 50,
      rootHTML: document.querySelector('#root')?.innerHTML?.substring(0, 300) || 'NO ROOT'
    }));

    console.log(`✓ URL: ${chatState.url}`);
    console.log(`✓ Has content: ${chatState.hasContent}`);
    console.log(`✓ Redirected: ${!chatState.url.includes('/chat')}`);
    console.log(`✓ Body preview: ${chatState.bodyText}`);

    await page.screenshot({ path: `${screenshotsDir}/03-chat.png`, fullPage: true });
    console.log(`📸 Screenshot: ${screenshotsDir}/03-chat.png`);

    // Test 4: Black Mirror (this one worked!)
    console.log('\n📍 TEST 4: Black Mirror Page');
    console.log('-'.repeat(80));

    await page.goto(`${BASE_URL}/black-mirror`, { waitUntil: 'networkidle2' });
    await new Promise(r => setTimeout(r, 3000));

    const blackMirrorState = await page.evaluate(() => {
      const text = document.body.innerText;
      return {
        url: window.location.href,
        bodyText: text.substring(0, 500),
        hasContent: text.length > 50,
        hasPremiumGate: text.toLowerCase().includes('premium'),
        hasBlackMirror: text.toLowerCase().includes('black mirror'),
        buttons: Array.from(document.querySelectorAll('button')).map(b => b.textContent?.trim()),
        hasUpload: text.toLowerCase().includes('upload')
      };
    });

    console.log(`✓ URL: ${blackMirrorState.url}`);
    console.log(`✓ Has content: ${blackMirrorState.hasContent}`);
    console.log(`✓ Has premium gate: ${blackMirrorState.hasPremiumGate}`);
    console.log(`✓ Has Black Mirror content: ${blackMirrorState.hasBlackMirror}`);
    console.log(`✓ Has upload section: ${blackMirrorState.hasUpload}`);
    console.log(`✓ Buttons: ${blackMirrorState.buttons.join(', ')}`);

    await page.screenshot({ path: `${screenshotsDir}/04-black-mirror.png`, fullPage: true });
    console.log(`📸 Screenshot: ${screenshotsDir}/04-black-mirror.png`);

    // Test 5: Click upgrade button
    console.log('\n📍 TEST 5: Premium Modal');
    console.log('-'.repeat(80));

    const upgradeClicked = await page.evaluate(() => {
      const btn = Array.from(document.querySelectorAll('button')).find(b =>
        b.textContent?.toLowerCase().includes('upgrade')
      );
      if (btn) {
        btn.click();
        return true;
      }
      return false;
    });

    if (upgradeClicked) {
      await new Promise(r => setTimeout(r, 2000));

      const modalState = await page.evaluate(() => {
        const text = document.body.innerText;
        return {
          hasModal: !!document.querySelector('[role="dialog"]'),
          modalText: text,
          has999: text.includes('9.99') || text.includes('$9'),
          has75: text.includes('$75') || text.includes('75'),
          has150: text.includes('$150') || text.includes('150'),
          subscribeButtons: Array.from(document.querySelectorAll('button')).filter(b =>
            b.textContent?.toLowerCase().includes('subscribe')
          ).map(b => b.textContent?.trim())
        };
      });

      console.log(`✓ Modal opened: ${modalState.hasModal}`);
      console.log(`✓ Has $9.99: ${modalState.has999}`);
      console.log(`✓ Has $75: ${modalState.has75}`);
      console.log(`✓ Has $150: ${modalState.has150}`);
      console.log(`✓ Subscribe buttons: ${modalState.subscribeButtons.join(', ')}`);

      await page.screenshot({ path: `${screenshotsDir}/05-premium-modal.png`, fullPage: true });
      console.log(`📸 Screenshot: ${screenshotsDir}/05-premium-modal.png`);
    }

    // Test 6: Responsive design
    console.log('\n📍 TEST 6: Responsive Design');
    console.log('-'.repeat(80));

    const viewports = [
      { name: 'Mobile', width: 375, height: 667 },
      { name: 'Tablet', width: 768, height: 1024 },
      { name: 'Desktop', width: 1920, height: 1080 }
    ];

    for (const vp of viewports) {
      await page.setViewport({ width: vp.width, height: vp.height });
      await page.goto(`${BASE_URL}/black-mirror`, { waitUntil: 'networkidle2' });
      await new Promise(r => setTimeout(r, 1500));

      const responsive = await page.evaluate(() => ({
        overflow: document.body.scrollWidth > window.innerWidth,
        hasContent: document.body.innerText.length > 50
      }));

      console.log(`✓ ${vp.name} (${vp.width}x${vp.height}): Overflow=${responsive.overflow}, Content=${responsive.hasContent}`);

      await page.screenshot({ path: `${screenshotsDir}/06-${vp.name.toLowerCase()}.png`, fullPage: true });
    }

    // Test 7: Performance
    console.log('\n📍 TEST 7: Performance Metrics');
    console.log('-'.repeat(80));

    await page.setViewport({ width: 1920, height: 1080 });
    await page.goto(`${BASE_URL}/black-mirror`, { waitUntil: 'load' });

    const metrics = await page.evaluate(() => {
      const perf = performance.getEntriesByType('navigation')[0];
      return {
        domContentLoaded: Math.round(perf.domContentLoadedEventEnd - perf.fetchStart),
        loadComplete: Math.round(perf.loadEventEnd - perf.fetchStart),
        domInteractive: Math.round(perf.domInteractive - perf.fetchStart)
      };
    });

    console.log(`✓ DOM Content Loaded: ${metrics.domContentLoaded}ms`);
    console.log(`✓ Load Complete: ${metrics.loadComplete}ms`);
    console.log(`✓ DOM Interactive: ${metrics.domInteractive}ms`);

    // Final Summary
    console.log('\n' + '='.repeat(80));
    console.log('✅ TESTING COMPLETE - All screenshots saved to:', screenshotsDir);
    console.log('='.repeat(80) + '\n');

  } catch (error) {
    console.error('\n❌ ERROR:', error.message);
  } finally {
    await browser.close();
  }
})();
