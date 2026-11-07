import { chromium } from 'playwright';

const target = process.argv[2];
if (!target) {
  console.error('Usage: node tools/web_view_test.mjs <web-url>');
  process.exit(2);
}

const browser = await chromium.launch({ headless: true });
const failures = [];
try {
  for (const viewport of [
    { name: 'desktop', width: 1440, height: 900 },
    { name: 'mobile', width: 390, height: 844 },
  ]) {
    const page = await browser.newPage({
      viewport: { width: viewport.width, height: viewport.height },
      deviceScaleFactor: 1,
    });
    page.on('pageerror', error => failures.push(`[${viewport.name}] ${error.message}`));

    const response = await page.goto(target, { waitUntil: 'domcontentloaded', timeout: 60000 });
    if (!response || !response.ok()) {
      failures.push(`[${viewport.name}] Web page returned HTTP ${response?.status() ?? 'no response'}`);
    }

    await page.waitForFunction(() => {
      const pane = document.querySelector('flt-glass-pane');
      const canvas = pane?.querySelector('canvas');
      return !!canvas && canvas.width > 0 && canvas.height > 0;
    }, { timeout: 90000 });

    const result = await page.evaluate(() => {
      const canvas = document.querySelector('flt-glass-pane canvas');
      const rect = canvas?.getBoundingClientRect();
      return {
        title: document.title,
        canvasWidth: canvas?.width ?? 0,
        canvasHeight: canvas?.height ?? 0,
        visibleWidth: rect?.width ?? 0,
        visibleHeight: rect?.height ?? 0,
        direction: document.documentElement.dir,
        language: document.documentElement.lang,
      };
    });

    if (!result.title.includes('Silsila')) failures.push(`[${viewport.name}] Unexpected page title: ${result.title}`);
    if (result.visibleWidth <= 0 || result.visibleHeight <= 0) failures.push(`[${viewport.name}] Flutter canvas is not visible`);
    console.log(`PASS WebView ${viewport.name}: ${JSON.stringify(result)}`);
    await page.close();
  }
} catch (error) {
  failures.push(error.stack || String(error));
} finally {
  await browser.close();
}

if (failures.length) {
  console.error('WebView browser test failed:\n' + failures.join('\n'));
  process.exit(1);
}
console.log('SUCCESS: Silsila Flutter Web rendered in desktop and mobile Chromium viewports.');
