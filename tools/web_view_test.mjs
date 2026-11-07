import { chromium } from 'playwright';
import { SourceMapConsumer } from 'source-map';

const target = process.argv[2];
if (!target) {
  console.error('Usage: node tools/web_view_test.mjs <web-url>');
  process.exit(2);
}

const browser = await chromium.launch({ headless: true });
const failures = [];
let sourceMapConsumer;
try {
  const mapResponse = await fetch(new URL('main.dart.js.map', target));
  if (mapResponse.ok) sourceMapConsumer = await new SourceMapConsumer(await mapResponse.json());
  else console.warn(`Dart source map unavailable: HTTP ${mapResponse.status}`);
} catch (error) {
  console.warn(`Could not load Dart source map: ${error.message}`);
}
const describePageError = error => {
  const frames = String(error.stack || '').split('\n').map(frame => {
    const match = frame.match(/main\.dart\.js:(\d+):(\d+)/);
    if (!match || !sourceMapConsumer) return frame;
    const original = sourceMapConsumer.originalPositionFor({
      line: Number(match[1]),
      column: Number(match[2]),
    });
    return original.source
      ? frame + ' => ' + original.source + ':' + original.line + ':' + original.column
      : frame;
  });
  const details = Object.getOwnPropertyNames(error)
    .filter(key => key !== 'stack')
    .map(key => key + '=' + String(error[key]));
  return 'name=' + error.name + '; message=' + (error.message || '(empty)') + '; ' + details.join('; ') + '\n' + frames.join('\n');
};
try {
  for (const viewport of [
    { name: 'desktop', width: 1440, height: 900 },
    { name: 'mobile', width: 390, height: 844 },
  ]) {
    const page = await browser.newPage({
      viewport: { width: viewport.width, height: viewport.height },
      deviceScaleFactor: 1,
    });
    page.on('pageerror', error => failures.push(`[${viewport.name}] pageerror: ${describePageError(error)}`));
    page.on('console', message => {
      if (message.type() === 'error') failures.push(`[${viewport.name}] console: ${message.text()} (location: ${JSON.stringify(message.location())})`);
    });
    page.on('requestfailed', request => failures.push(`[${viewport.name}] request failed: ${request.url()} - ${request.failure()?.errorText ?? 'unknown'}`));

    const response = await page.goto(target, { waitUntil: 'domcontentloaded', timeout: 60000 });
    if (!response || !response.ok()) {
      failures.push(`[${viewport.name}] Web page returned HTTP ${response?.status() ?? 'no response'}`);
    }

    const findRenderedCanvas = () => {
      const findInRoot = root => {
        const direct = root.querySelector?.('canvas');
        if (direct && direct.width > 0 && direct.height > 0) return direct;
        for (const element of root.querySelectorAll?.('*') ?? []) {
          if (element.shadowRoot) {
            const nested = findInRoot(element.shadowRoot);
            if (nested) return nested;
          }
        }
        return null;
      };
      return findInRoot(document);
    };

    try {
      await page.waitForFunction(() => {
        const findInRoot = root => {
          const direct = root.querySelector?.('canvas');
          if (direct && direct.width > 0 && direct.height > 0) return true;
          for (const element of root.querySelectorAll?.('*') ?? []) {
            if (element.shadowRoot && findInRoot(element.shadowRoot)) return true;
          }
          return false;
        };
        return findInRoot(document);
      }, null, { timeout: 90000 });
    } catch (error) {
      const diagnostics = await page.evaluate(() => ({
        url: location.href,
        title: document.title,
        readyState: document.readyState,
        flutterGlassPane: !!document.querySelector('flt-glass-pane'),
        flutterView: !!document.querySelector('flutter-view'),
        bodyText: document.body?.innerText?.slice(0, 1000) ?? '',
        bodyHtml: document.body?.innerHTML?.slice(0, 3000) ?? '',
        scripts: [...document.scripts].map(script => script.src).filter(Boolean),
      }));
      console.error(`[${viewport.name}] Flutter render diagnostics: ${JSON.stringify(diagnostics)}`);
      throw error;
    }

    const result = await page.evaluate(() => {
      const findInRoot = root => {
        const direct = root.querySelector?.('canvas');
        if (direct && direct.width > 0 && direct.height > 0) return direct;
        for (const element of root.querySelectorAll?.('*') ?? []) {
          if (element.shadowRoot) {
            const nested = findInRoot(element.shadowRoot);
            if (nested) return nested;
          }
        }
        return null;
      };
      const canvas = findInRoot(document);
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
  sourceMapConsumer?.destroy?.();
}

if (failures.length) {
  console.error('WebView browser test failed:\n' + failures.join('\n'));
  process.exit(1);
}
console.log('SUCCESS: Silsila Flutter Web rendered in desktop and mobile Chromium viewports.');
