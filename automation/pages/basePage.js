const AppiumUtils = require('../utilities/appiumUtils');
const GestureUtils = require('../utilities/gestureUtils');

class BasePage {
  constructor(driver) {
    this.driver = driver;
  }

  async waitForElement(selector, timeoutMs) {
    return AppiumUtils.waitForElement(this.driver, selector, timeoutMs);
  }

  async waitForDisplayed(selector, timeoutMs) {
    return AppiumUtils.waitForDisplayed(this.driver, selector, timeoutMs);
  }

  async waitForClickable(selector, timeoutMs) {
    return AppiumUtils.waitForClickable(this.driver, selector, timeoutMs);
  }

  async click(selector, timeoutMs) {
    await AppiumUtils.click(this.driver, selector, timeoutMs);
  }

  async type(selector, text, timeoutMs) {
    await AppiumUtils.type(this.driver, selector, text, timeoutMs);
  }

  async getElementText(selector, timeoutMs = 10000) {
    const el = await this.waitForDisplayed(selector, timeoutMs);
    return await el.getText();
  }

  /**
   * Returns true if the element is visible (displayed) within the given timeout.
   * Does NOT throw on timeout – returns false instead.
   */
  async isElementVisible(selector, timeoutMs = 5000) {
    try {
      const el = await this.driver.$(selector);
      // Give it up to timeoutMs to appear
      await el.waitForDisplayed({ timeout: timeoutMs });
      return await el.isDisplayed();
    } catch (e) {
      return false;
    }
  }

  async hideKeyboard() {
    await AppiumUtils.hideKeyboard(this.driver);
  }

  async getToastOrSnackbar(timeoutMs) {
    return AppiumUtils.getToastOrSnackbar(this.driver, timeoutMs);
  }

  async scrollUntilVisible(targetSelector, maxSwipes, direction) {
    return GestureUtils.scrollUntilVisible(this.driver, targetSelector, maxSwipes, direction);
  }
}

module.exports = BasePage;
