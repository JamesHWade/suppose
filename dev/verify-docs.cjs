// Run after dev/build-docs.R, with docs/ served over HTTP.
// Usage: node dev/verify-docs.cjs [http://127.0.0.1:3910]
const { chromium } = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

(async () => {
  const base = process.argv[2] || 'http://127.0.0.1:3910';
  const articles = [
    'suppose', 'workbench', 'prior-consequences', 'measurements',
    'regression', 'research-design', 'methods', 'terminal'
  ];
  const pages = ['index.html', 'articles/index.html', 'reference/index.html',
    ...articles.map(name => `articles/${name}.html`)];
  const browser = await chromium.launch({ channel: 'chrome', headless: true });
  const problems = [];
  const links = new Set();
  fs.mkdirSync('artifacts', { recursive: true });
  try {
    const page = await browser.newPage();
    page.on('pageerror', error => problems.push(error.message));
    for (const file of pages) {
      const response = await page.goto(`${base}/${file}`);
      assert.equal(response.status(), 200, file);
      for (const width of [1360, 390]) {
        await page.setViewportSize({ width, height: 950 });
        assert.ok(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1),
          `${file}: horizontal overflow at ${width}px`);
      }
      const images = await page.locator('main img').evaluateAll(elements =>
        elements.map(image => ({ src: image.src, loaded: image.complete && image.naturalWidth > 0,
          alt: image.getAttribute('alt'), decorative: image.classList.contains('logo') })));
      for (const image of images) {
        assert.ok(image.loaded, `Missing image: ${image.src}`);
        assert.ok(image.decorative ? image.alt !== null : image.alt && image.alt.trim(),
          `Missing alternative text: ${image.src}`);
      }
      for (const href of await page.locator('a[href]').evaluateAll(elements => elements.map(a => a.href))) {
        if (href.startsWith(`${base}/`)) links.add(href);
      }
    }
    // Check both destination files and section anchors on the published reader routes.
    const linkFailures = await page.evaluate(async hrefs => {
      const cache = new Map();
      const failures = [];
      for (const href of hrefs) {
        const url = new URL(href);
        const file = `${url.origin}${url.pathname}`;
        if (!cache.has(file)) {
          const response = await fetch(file);
          cache.set(file, { ok: response.ok,
            document: new DOMParser().parseFromString(await response.text(), 'text/html') });
        }
        const item = cache.get(file);
        if (!item.ok) failures.push(href);
        else if (url.hash && !item.document.getElementById(decodeURIComponent(url.hash.slice(1)))) {
          failures.push(href);
        }
      }
      return failures;
    }, [...links]);
    // pkgdown adds some index-heading IDs in JavaScript after page load.
    for (const href of linkFailures) {
      const response = await page.goto(href);
      if (response) assert.equal(response.status(), 200, href);
      const fragment = decodeURIComponent(new URL(href).hash.slice(1));
      assert.ok(fragment && await page.evaluate(id => Boolean(document.getElementById(id)), fragment), href);
    }

    await page.setViewportSize({ width: 1360, height: 950 });
    await page.goto(base);
    await page.getByRole('button', { name: 'Guides', exact: true }).click();
    await page.getByRole('link', { name: 'Fit and revise a regression', exact: true }).click();
    await page.waitForURL('**/articles/regression.html');
    await page.goto(base);
    await page.getByRole('combobox', { name: 'Search site' }).focus();
    await page.waitForFunction(() => !document.getElementById('search-input').classList.contains('loading'));
    await page.getByRole('combobox', { name: 'Search site' }).fill('regression');
    await page.getByRole('option').first().waitFor();
    const matches = await page.getByRole('option').allTextContents();
    assert.ok(matches.some(text => text.includes('Reference')));
    assert.ok(matches.some(text => text.includes('Articles')));
    assert.ok(matches.every(text => !/backlog|WORK-|acceptance report/i.test(text)));
    await page.getByRole('combobox').press('ArrowDown');
    await page.getByRole('combobox').press('Enter');
    await page.waitForURL(url => url.pathname !== '/');
    await page.goto(base);
    await page.keyboard.press('Tab');
    assert.match(await page.locator(':focus').innerText(), /skip to contents/i);
    await page.keyboard.press('Enter');
    assert.equal(await page.locator(':focus').getAttribute('id'), 'main');
    await page.goto(base);
    await page.screenshot({ path: 'artifacts/docs-home-desktop.png', fullPage: true });
    await page.setViewportSize({ width: 390, height: 844 });
    await page.screenshot({ path: 'artifacts/docs-home-mobile.png', fullPage: true });
    await page.getByRole('button', { name: 'Toggle navigation' }).click();
    await page.getByRole('navigation', { name: 'Site navigation' }).getByRole('link', { name: 'Get started', exact: true }).click();
    await page.waitForURL('**/articles/suppose.html');
    await page.screenshot({ path: 'artifacts/docs-start-mobile.png', fullPage: true });
    await page.setViewportSize({ width: 1360, height: 950 });
    await page.goto(`${base}/articles/regression.html`);
    await page.locator('main img:not(.logo)').first().scrollIntoViewIfNeeded();
    await page.screenshot({ path: 'artifacts/docs-regression-desktop.png' });
    assert.deepEqual(problems, []);
    const result = `${pages.length} pages checked at desktop and mobile widths; ${links.size} local links and anchors valid.\n` +
      'Figures load with alternative text; guide navigation, keyboard search, skip link, and mobile navigation pass.\n' +
      'No page JavaScript errors; historical development notes excluded from search.\n';
    fs.writeFileSync(path.join('artifacts', 'docs-browser-verification.log'), result);
    console.log(result);
  } finally {
    await browser.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
