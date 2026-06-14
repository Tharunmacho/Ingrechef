const fs = require('fs');
const path = require('path');
const logger = require('./logger');

class AppiumUtils {
  static async waitForElement(driver, selector, timeoutMs = 15000) {
    logger.debug(`Waiting for element: ${selector}`);
    const el = await driver.$(selector);
    await el.waitForExist({ timeout: timeoutMs });
    return el;
  }

  static async waitForDisplayed(driver, selector, timeoutMs = 15000) {
    logger.debug(`Waiting for element to be displayed: ${selector}`);
    const el = await driver.$(selector);
    await el.waitForDisplayed({ timeout: timeoutMs });
    return el;
  }

  static async waitForClickable(driver, selector, timeoutMs = 15000) {
    logger.debug(`Waiting for element to be clickable: ${selector}`);
    return await this.waitForDisplayed(driver, selector, timeoutMs);
  }

  static async click(driver, selector, timeoutMs = 15000) {
    logger.debug(`Clicking element: ${selector}`);
    const el = await this.waitForClickable(driver, selector, timeoutMs);
    await el.click();
  }

  static async type(driver, selector, text, timeoutMs = 15000) {
    logger.debug(`Typing text "${text}" into element: ${selector}`);
    const el = await this.waitForDisplayed(driver, selector, timeoutMs);
    await el.clearValue();
    if (text !== '') await el.setValue(text);
  }

  static async hideKeyboard(driver) {
    try {
      if (await driver.isKeyboardShown()) {
        logger.info('Hiding active soft keyboard...');
        await driver.hideKeyboard();
      }
    } catch (e) {
      logger.warn('Failed to hide soft keyboard: ' + e.message);
    }
  }

  /**
   * Flutter SnackBars expose their message via @content-desc on android.view.View nodes.
   * We poll for known validation message keywords in content-desc.
   */
  static async getToastOrSnackbar(driver, timeoutMs = 7000) {
    logger.info('Searching for active Toast/SnackBar validation message...');

    // Strategy 1: Native Android Toast
    try {
      const toastEl = await driver.$('//android.widget.Toast');
      if (await toastEl.isExisting()) {
        const text = await toastEl.getText();
        if (text && text.trim().length > 0) {
          logger.info(`Captured Toast message: "${text}"`);
          return text;
        }
      }
    } catch (_) {}

    // Strategy 2: Poll for Flutter snackbar via @content-desc
    // We require length > 10 to avoid picking up static UI labels like "Password" or "Email"
    const validationKeywords = [
      'Please enter email and password',
      'Please fill in all fields',
      'Passwords do not match',
      'passwords do not match',
      'Account created',
      'Login failed',
      'login failed',
      'Login Failed',
      'Sign up failed',
      'failed',
      'invalid',
      'Error',
      'error',
      'not found',
      'Incorrect',
      'mismatch',
      'already',
      'updated',
      'credentials',
    ];

    const deadline = Date.now() + timeoutMs;
    while (Date.now() < deadline) {
      // Check content-desc based (Flutter SnackBar text)
      for (const keyword of validationKeywords) {
        try {
          const el = await driver.$(`//*[contains(@content-desc, "${keyword}")]`);
          if (await el.isExisting()) {
            const desc = await el.getAttribute('content-desc');
            // Must be longer than single-word UI label (real snackbars are sentences)
            if (desc && desc.trim().length > 8) {
              logger.info(`Captured SnackBar via content-desc: "${desc}"`);
              return desc;
            }
          }
        } catch (_) {}
      }

      // Also check @text for any toast/snackbar text nodes
      for (const keyword of validationKeywords) {
        try {
          const el = await driver.$(`//*[contains(@text, "${keyword}")]`);
          if (await el.isExisting()) {
            const txt = await el.getText();
            if (txt && txt.trim().length > 8) {
              logger.info(`Captured SnackBar via text: "${txt}"`);
              return txt;
            }
          }
        } catch (_) {}
      }

      await driver.pause(400);
    }

    logger.warn('No snackbar/toast message found within timeout.');
    return null;
  }

  static async captureScreenshot(driver, testName) {
    const screenshotDir = path.join(__dirname, '..', 'reports', 'failures');
    if (!fs.existsSync(screenshotDir)) {
      fs.mkdirSync(screenshotDir, { recursive: true });
    }
    const sanitizedName = testName.replace(/[^a-zA-Z0-9]/g, '_');
    const filename = `${sanitizedName}_${Date.now()}.png`;
    const filepath = path.join(screenshotDir, filename);
    
    try {
      logger.info(`Saving screenshot: ${filename}`);
      await driver.saveScreenshot(filepath);
      return filepath;
    } catch (e) {
      logger.error('Failed to capture screenshot: ' + e.message);
      return null;
    }
  }

  static async captureDeviceLogs(driver, testName) {
    const logsDir = path.join(__dirname, '..', 'reports', 'failures');
    if (!fs.existsSync(logsDir)) {
      fs.mkdirSync(logsDir, { recursive: true });
    }
    const sanitizedName = testName.replace(/[^a-zA-Z0-9]/g, '_');
    const filename = `${sanitizedName}_logcat_${Date.now()}.txt`;
    const filepath = path.join(logsDir, filename);

    try {
      logger.info(`Capturing logcat: ${filename}`);
      const logTypes = await driver.getLogTypes();
      if (logTypes.includes('logcat')) {
        const logs = await driver.getLogs('logcat');
        const entries = logs.slice(-150).map(e => `[${new Date(e.timestamp).toISOString()}] [${e.level}] ${e.message}`).join('\n');
        fs.writeFileSync(filepath, entries);
        return filepath;
      }
    } catch (e) {
      logger.error('Failed to capture logcat: ' + e.message);
    }
    return null;
  }

  static async getCurrentActivity(driver) {
    try {
      return await driver.getCurrentActivity();
    } catch (e) {
      logger.warn('Failed to get current activity: ' + e.message);
      return 'UnknownActivity';
    }
  }

  static async retry(fn, retries = 2, delay = 1000) {
    for (let i = 0; i <= retries; i++) {
      try {
        return await fn();
      } catch (err) {
        if (i === retries) throw err;
        logger.warn(`Retry ${i + 1}/${retries}: ${err.message}`);
        await new Promise(resolve => setTimeout(resolve, delay));
      }
    }
  }
}

module.exports = AppiumUtils;
