const BasePage = require('./basePage');
const logger = require('../utilities/logger');

/**
 * ProfilePage - Page Object for the Profile screen.
 *
 * Profile screen has a bottom "Log Out" bar (GestureDetector).
 * Flutter renders it as android.view.View with @content-desc="Log Out", clickable=true.
 * The AlertDialog confirm button is also content-desc="Log Out".
 */
class ProfilePage extends BasePage {
  constructor(driver) {
    super(driver);
  }

  // ── Selectors ─────────────────────────────────────────────────────────────
  get logoutBtn()        { return '//*[@content-desc="Log Out" and @clickable="true"]'; }
  get cancelDialogBtn()  { return '//*[@content-desc="Cancel" and @clickable="true"]'; }

  // ── Methods ───────────────────────────────────────────────────────────────
  async logout() {
    logger.info('Performing Logout sequence on Profile screen...');

    // Click the "Log Out" bottom bar
    const logoutEls = await this.driver.$$('//*[@content-desc="Log Out" and @clickable="true"]');
    if (logoutEls.length === 0) {
      throw new Error('"Log Out" button not found on Profile screen (content-desc)');
    }
    // Click the first one (bottom bar)
    await logoutEls[0].click();
    logger.info('Tapped Log Out bar');
    await this.driver.pause(1000);

    // Wait for dialog and confirm
    logger.info('Waiting for logout confirmation dialog...');
    const confirmEls = await this.driver.$$('//*[@content-desc="Log Out" and @clickable="true"]');
    if (confirmEls.length > 1) {
      await confirmEls[confirmEls.length - 1].click();
    } else if (confirmEls.length === 1) {
      await confirmEls[0].click();
    } else {
      // Try android.widget.Button as dialog uses ElevatedButton
      const btn = await this.driver.$('//android.widget.Button[@content-desc="Log Out" or contains(@text, "Log Out")]');
      await btn.click();
    }
    logger.info('Logout confirmed');
    await this.driver.pause(2500); // Wait for navigation back to LoginScreen
  }

  async verifyProfileDetails(expectedName, expectedEmail) {
    logger.info(`Checking profile content-desc for name="${expectedName}" and email="${expectedEmail}"...`);
    const emailVisible = await this.isElementVisible(`//*[@content-desc="${expectedEmail}"]`);
    const nameVisible  = await this.isElementVisible(`//*[@content-desc="${expectedName}"]`);
    return emailVisible && nameVisible;
  }
}

module.exports = ProfilePage;
