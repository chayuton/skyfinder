// Temporary: drives the built web app in headless Chromium with synthetic
// DeviceOrientation events and prints crops of the compass as base64 PNGs.
import { chromium } from 'playwright';

const BASE = 'http://127.0.0.1:8080/';
const VIEW = { width: 390, height: 844 };
const CLIP = { x: 250, y: 640, width: 140, height: 150 };
const TAP = { x: 352, y: 737 };

const browser = await chromium.launch({
  args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'],
});
const log = (...a) => console.log(...a);

// Records every requestPermission call: the input event it ran inside, its
// arguments, and how it was answered.
const spy = () => {
  window.__calls = [];
  const orig = window.DeviceOrientationEvent && DeviceOrientationEvent.requestPermission;
  if (typeof orig !== 'function') return;
  DeviceOrientationEvent.requestPermission = function (...args) {
    const ev = window.event;
    window.__calls.push(`${ev ? ev.type : 'none'}(${JSON.stringify(args)})`);
    return orig.apply(this, args).then(
      (r) => { window.__calls.push('-> ' + r); return r; },
      (e) => { window.__calls.push('-> ' + e.name); throw e; });
  };
};

// iOS Safari: no absolute event, relative alpha plus webkitCompassHeading, and
// a prompt that only answers from inside an input event, as WebKit does.
const ios = () => {
  try { delete window.ondeviceorientationabsolute; } catch (e) { /* */ }
  try { delete Window.prototype.ondeviceorientationabsolute; } catch (e) { /* */ }
  window.__calls = [];
  DeviceOrientationEvent.requestPermission = function (...args) {
    const ev = window.event;
    window.__calls.push(`${ev ? ev.type : 'none'}(${JSON.stringify(args)})`);
    if (ev && /^(pointerup|touchend|click|mouseup)$/.test(ev.type)) return Promise.resolve('granted');
    return Promise.reject(new DOMException('Requesting device orientation access requires a user gesture to prompt', 'NotAllowedError'));
  };
};

async function open(name, { init, grant } = {}) {
  const context = await browser.newContext({
    viewport: VIEW, deviceScaleFactor: 2, isMobile: true, hasTouch: true, locale: 'th-TH',
  });
  if (grant) await context.grantPermissions(grant, { origin: BASE.replace(/\/$/, '') });
  await context.addInitScript(init || spy);
  const page = await context.newPage();
  const errors = [];
  page.on('pageerror', (e) => errors.push('pageerror: ' + e.message));
  page.on('console', (m) => { if (m.type() === 'error') errors.push('console: ' + m.text()); });
  await page.goto(BASE, { waitUntil: 'load' });
  await page.waitForFunction(() => !!document.querySelector('flutter-view'), null, { timeout: 90000 });
  await page.waitForFunction(() => !document.getElementById('skyfinder-loader'), null, { timeout: 90000 });
  await page.waitForTimeout(2500);
  log(`${name} requestPermission=${await page.evaluate(() => typeof DeviceOrientationEvent.requestPermission)}`
    + ` absoluteHandler=${await page.evaluate(() => 'ondeviceorientationabsolute' in window)}`);
  return { context, page, errors };
}

async function calls(page, name, when) {
  log(`${name} calls ${when}: ${JSON.stringify(await page.evaluate(() => window.__calls))}`);
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

// Android Chrome with motion sensors allowed, its default.
{
  const name = 'android';
  const { context, page, errors } = await open(name, { grant: ['accelerometer', 'gyroscope', 'magnetometer'] });
  await calls(page, name, 'at launch');
  await shot(page, 'android-0-launch');
  await orient(page, 'deviceorientationabsolute', 0, 40, 0);
  await shot(page, 'android-1-north');
  await orient(page, 'deviceorientationabsolute', 270, 40, 0);
  await shot(page, 'android-2-east');
  await shot(page, 'android-2-east-full', true);
  await orient(page, 'deviceorientationabsolute', 90, 150, 0);
  await shot(page, 'android-3-west-aimed-up');
  await orient(page, 'deviceorientationabsolute', 90, 0, 0);
  await shot(page, 'android-4-west-flat');
  log(`ERRORS ${name} ${JSON.stringify(errors)}`);
  await context.close();
}

// Android Chrome with motion sensors set to ask.
{
  const name = 'android-ask';
  const { context, page, errors } = await open(name);
  await calls(page, name, 'at launch');
  await shot(page, 'ask-0-launch');
  await page.touchscreen.tap(TAP.x, TAP.y);
  await page.waitForTimeout(1500);
  await calls(page, name, 'after tap');
  await shot(page, 'ask-1-after-tap');
  log(`ERRORS ${name} ${JSON.stringify(errors)}`);
  await context.close();
}

// iOS Safari.
{
  const name = 'ios';
  const { context, page, errors } = await open(name, { init: ios });
  await calls(page, name, 'at launch');
  await shot(page, 'ios-0-launch');
  await page.touchscreen.tap(TAP.x, TAP.y);
  await page.waitForTimeout(800);
  await calls(page, name, 'after tap');
  await shot(page, 'ios-1-after-tap');
  // alpha counts from an arbitrary zero: 300 while the top edge faces 45.
  await orient(page, 'deviceorientation', 300, 40, 0, { webkitCompassHeading: 45, webkitCompassAccuracy: 10 });
  await shot(page, 'ios-2-45');
  await orient(page, 'deviceorientation', 270, 40, 0, { webkitCompassHeading: 75, webkitCompassAccuracy: 10 });
  await shot(page, 'ios-3-75');
  // Camera 60 degrees up: the top-edge compass would now say 255 (behind).
  await orient(page, 'deviceorientation', 270, 150, 0, { webkitCompassHeading: 255, webkitCompassAccuracy: 10 });
  await shot(page, 'ios-4-75-aimed-up');
  // Tap again: the map locks to the compass, facing direction at the bottom.
  await page.touchscreen.tap(TAP.x, TAP.y);
  await orient(page, 'deviceorientation', 270, 40, 0, { webkitCompassHeading: 75, webkitCompassAccuracy: 10 });
  await shot(page, 'ios-5-locked-full', true);
  log(`ERRORS ${name} ${JSON.stringify(errors)}`);
  await context.close();
}

await browser.close();
log('DONE');
