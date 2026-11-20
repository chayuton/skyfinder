// Temporary: drives the built web app in headless Chromium with synthetic
// DeviceOrientation events and prints crops of the compass as base64 PNGs.
import { chromium } from 'playwright';

const BASE = 'http://127.0.0.1:8080/';
const VIEW = { width: 390, height: 844 };
const CLIP = { x: 250, y: 640, width: 140, height: 150 };

const browser = await chromium.launch({
  args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'],
});
const log = (...a) => console.log(...a);

async function open(init) {
  const context = await browser.newContext({
    viewport: VIEW, deviceScaleFactor: 2, isMobile: true, hasTouch: true, locale: 'th-TH',
  });
  if (init) await context.addInitScript(init);
  const page = await context.newPage();
  const errors = [];
  page.on('pageerror', (e) => errors.push('pageerror: ' + e.message));
  page.on('console', (m) => { if (m.type() === 'error') errors.push('console: ' + m.text()); });
  await page.goto(BASE, { waitUntil: 'load' });
  await page.waitForFunction(() => !!document.querySelector('flutter-view'), null, { timeout: 90000 });
  await page.waitForFunction(() => !document.getElementById('skyfinder-loader'), null, { timeout: 90000 });
  await page.waitForTimeout(2500);
  return { context, page, errors };
}

async function shot(page, name, full = false) {
  const buf = await page.screenshot(full ? { scale: 'css' } : { clip: CLIP });
  log(`SHOT ${name} ${buf.toString('base64')}`);
}

async function orient(page, type, alpha, beta, gamma, extra) {
  await page.evaluate(([type, alpha, beta, gamma, extra]) => {
    for (let i = 0; i < 3; i++) {
      const e = new DeviceOrientationEvent(type, {
        alpha, beta, gamma, absolute: type === 'deviceorientationabsolute',
      });
      if (extra) for (const [k, v] of Object.entries(extra)) Object.defineProperty(e, k, { value: v });
      window.dispatchEvent(e);
    }
  }, [type, alpha, beta, gamma, extra || null]);
  await page.waitForTimeout(700);
}

// Android Chrome: absolute alpha, no permission prompt.
{
  const { context, page, errors } = await open(null);
  await shot(page, 'android-0-before');
  await orient(page, 'deviceorientationabsolute', 0, 40, 0);
  await shot(page, 'android-1-north');
  await orient(page, 'deviceorientationabsolute', 270, 40, 0);
  await shot(page, 'android-2-east');
  await shot(page, 'android-2-east-full', true);
  await orient(page, 'deviceorientationabsolute', 90, 150, 0);
  await shot(page, 'android-3-west-aimed-up');
  log('ERRORS android ' + JSON.stringify(errors));
  await context.close();
}

// iOS Safari: relative alpha, webkitCompassHeading, and a permission prompt
// that only answers from inside an input event, as WebKit does.
const iosInit = () => {
  try { delete Window.prototype.ondeviceorientationabsolute; } catch (e) { /* */ }
  window.__calls = [];
  DeviceOrientationEvent.requestPermission = function () {
    const ev = window.event;
    window.__calls.push(ev ? ev.type : 'none');
    if (ev && /^(pointerup|touchend|click|mouseup)$/.test(ev.type)) return Promise.resolve('granted');
    return Promise.reject(new DOMException('Requesting device orientation access requires a user gesture to prompt', 'NotAllowedError'));
  };
};
{
  const { context, page, errors } = await open(iosInit);
  log('IOS absolute-handler-present ' + await page.evaluate(() => 'ondeviceorientationabsolute' in window));
  log('IOS calls-before-tap ' + JSON.stringify(await page.evaluate(() => window.__calls)));
  await shot(page, 'ios-0-before-tap');
  await page.touchscreen.tap(352, 737);
  await page.waitForTimeout(800);
  log('IOS calls-after-tap ' + JSON.stringify(await page.evaluate(() => window.__calls)));
  await shot(page, 'ios-1-after-tap');
  // alpha counts from an arbitrary zero: 300 while the top edge faces 45.
  await orient(page, 'deviceorientation', 300, 40, 0, { webkitCompassHeading: 45, webkitCompassAccuracy: 10 });
  await shot(page, 'ios-2-45');
  await orient(page, 'deviceorientation', 270, 40, 0, { webkitCompassHeading: 75, webkitCompassAccuracy: 10 });
  await shot(page, 'ios-3-75');
  // Camera 60 degrees up: the top-edge compass would now say 255 (behind).
  await orient(page, 'deviceorientation', 270, 150, 0, { webkitCompassHeading: 255, webkitCompassAccuracy: 10 });
  await shot(page, 'ios-4-75-aimed-up');
  await shot(page, 'ios-4-full', true);
  log('ERRORS ios ' + JSON.stringify(errors));
  await context.close();
}

await browser.close();
log('DONE');
