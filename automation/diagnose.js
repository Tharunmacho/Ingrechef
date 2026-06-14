/**
 * Diagnostic script: launches the app, waits for login screen,
 * then prints ALL text nodes and EditText elements found.
 */
const { remote } = require('webdriverio');
const { execSync } = require('child_process');
require('dotenv').config();

async function main() {
  // Detect device
  const stdout = execSync('adb devices').toString();
  const lines = stdout.split('\n');
  let udid = null;
  for (let i = 1; i < lines.length; i++) {
    const line = lines[i].trim();
    if (line && line.includes('\tdevice')) {
      udid = line.split('\t')[0];
      break;
    }
  }
  console.log('Using device:', udid);

  const platformVersion = udid
    ? execSync(`adb -s ${udid} shell getprop ro.build.version.release`).toString().trim()
    : '16';
  console.log('Android version:', platformVersion);

  const path = require('path');
  const apkPath = path.resolve(__dirname, '../build/app/outputs/flutter-apk/app-debug.apk');

  const caps = {
    platformName: 'Android',
    'appium:automationName': 'UiAutomator2',
    'appium:deviceName': udid || 'Android Device',
    'appium:udid': udid,
    'appium:platformVersion': platformVersion,
    'appium:app': apkPath,
    'appium:noReset': false,
    'appium:fullReset': false,
    'appium:newCommandTimeout': 300,
  };

  const driver = await remote({
    hostname: '127.0.0.1',
    port: 4723,
    path: '/',
    capabilities: caps,
    logLevel: 'error'
  });

  try {
    console.log('\n=== App launched. Waiting 7s for splash screen... ===\n');
    await driver.pause(7000);

    // Dump all text nodes
    console.log('=== ALL VISIBLE TEXT NODES ===');
    const allTexts = await driver.$$('//*[@text!="" and string-length(@text) > 0]');
    for (const el of allTexts) {
      try {
        const txt = await el.getText();
        const cls = await el.getAttribute('class');
        const displayed = await el.isDisplayed();
        const clickable = await el.getAttribute('clickable');
        if (txt && txt.trim()) {
          console.log(`  [${displayed ? 'VISIBLE' : 'HIDDEN'}][${clickable === 'true' ? 'CLICK' : '-----'}] class=${cls} | text="${txt}"`);
        }
      } catch (_) {}
    }

    // Dump all EditText elements
    console.log('\n=== ALL EDITTEXT ELEMENTS ===');
    const edits = await driver.$$('//android.widget.EditText');
    for (let i = 0; i < edits.length; i++) {
      try {
        const txt = await edits[i].getText();
        const hint = await edits[i].getAttribute('hint');
        const pwd = await edits[i].getAttribute('password');
        const displayed = await edits[i].isDisplayed();
        const enabled = await edits[i].getAttribute('enabled');
        console.log(`  EditText[${i + 1}]: displayed=${displayed} enabled=${enabled} password=${pwd} hint="${hint}" text="${txt}"`);
      } catch (e) {
        console.log(`  EditText[${i + 1}]: ERROR - ${e.message}`);
      }
    }

    // Show page source snippet
    console.log('\n=== SAVING PAGE SOURCE TO diagnose_output.xml ===');
    const source = await driver.getPageSource();
    require('fs').writeFileSync('diagnose_output.xml', source);
    console.log(`Saved ${source.length} chars to diagnose_output.xml`);

  } finally {
    await driver.deleteSession();
    console.log('\n=== Session closed ===');
  }
}

main().catch(err => {
  console.error('FATAL:', err.message);
  process.exit(1);
});
