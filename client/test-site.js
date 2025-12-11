import puppeteer from 'puppeteer';

(async () => {
  let browser;
  try {
    browser = await puppeteer.launch({
      headless: 'new',
      args: ['--no-sandbox', '--disable-setuid-sandbox']
    });

    const page = await browser.newPage();

    // Collect console errors
    const errors = [];
    page.on('console', msg => {
      if (msg.type() === 'error') {
        errors.push(msg.text());
      }
    });

    page.on('pageerror', err => {
      errors.push(err.message);
    });

    console.log('Loading https://justlay.me...');
    await page.goto('https://justlay.me', {
      waitUntil: 'networkidle2',
      timeout: 30000
    });

    // Wait a bit for any delayed errors
    await new Promise(resolve => setTimeout(resolve, 2000));

    // Check if main app container exists
    const appExists = await page.evaluate(() => {
      return document.getElementById('root') !== null;
    });

    // Check for any React error messages in the DOM
    const hasReactError = await page.evaluate(() => {
      const body = document.body.textContent || '';
      return body.includes('Cannot read properties of undefined') ||
             body.includes('createContext') ||
             body.includes('React error');
    });

    console.log('\n=== SITE STATUS ===');
    console.log('App root element exists:', appExists);
    console.log('React errors in DOM:', hasReactError);
    console.log('Console errors found:', errors.length);

    if (errors.length > 0) {
      console.log('\n=== CONSOLE ERRORS ===');
      errors.forEach((err, i) => {
        console.log(`${i + 1}. ${err}`);
      });
    } else {
      console.log('\n✓ No console errors detected!');
    }

    // Get page title
    const title = await page.title();
    console.log('\nPage title:', title);

    // Check if any content loaded
    const bodyText = await page.evaluate(() => {
      return document.body.innerText.slice(0, 200);
    });

    if (bodyText.length > 10) {
      console.log('\n✓ Page content loaded successfully');
      console.log('First 200 chars:', bodyText);
    }

  } catch (error) {
    console.error('Test failed:', error.message);
    process.exit(1);
  } finally {
    if (browser) {
      await browser.close();
    }
  }

  console.log('\n=== TEST COMPLETE ===');
})();