const BasePage = require('./basePage');
const logger = require('../utilities/logger');

/**
 * IngredientsPage - Page Object for the Ingredient Management screen.
 *
 * Flutter views use @content-desc (not @text).
 * The ingredient input is an android.widget.EditText (hint="Type an ingredient...").
 * The add button is a GestureDetector (android.view.View) with no content-desc — use coordinate tap.
 */
class IngredientsPage extends BasePage {
  constructor(driver) {
    super(driver);
  }

  // ── Selectors ─────────────────────────────────────────────────────────────
  get ingredientInput() {
    return '//android.widget.EditText[contains(@hint, "ingredient")]';
  }
  get clearAllDialogBtn() {
    return '//*[@content-desc="Clear All" or @text="Clear All"]';
  }

  // ── Methods ───────────────────────────────────────────────────────────────
  async addIngredient(name) {
    logger.info(`Adding ingredient to pantry: "${name}"`);

    // Type into the input field
    const inputEl = await this.driver.$('//android.widget.EditText');
    await inputEl.waitForDisplayed({ timeout: 15000 });
    await inputEl.click();
    await this.driver.pause(300);
    await inputEl.clearValue();
    await inputEl.setValue(name);
    await this.driver.pause(300);

    // Hide keyboard first
    await this.hideKeyboard();
    await this.driver.pause(500);

    // Tap the add button by coordinate (it's to the right of the input)
    try {
      const windowSize = await this.driver.getWindowSize();
      const location = await inputEl.getLocation();
      const size = await inputEl.getSize();
      // Add button is a 50x50 container to the right of the TextField
      const tapX = windowSize.width - 100;
      const tapY = location.y + size.height / 2;
      logger.info(`Tapping add button at (${Math.round(tapX)}, ${Math.round(tapY)})`);
      await this.driver.action('pointer')
        .move({ x: Math.round(tapX), y: Math.round(tapY) })
        .down()
        .up()
        .perform();
    } catch (e) {
      logger.error('Coordinate tap for add button failed: ' + e.message);
      throw e;
    }

    await this.driver.pause(2000); // Wait for API + list reload
  }

  async verifyIngredientExists(name) {
    logger.info(`Verifying if ingredient "${name}" exists in pantry list...`);
    const nameLower = name.toLowerCase();
    const selector = `//*[contains(translate(@content-desc, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz'), "${nameLower}")]`;
    return await this.isElementVisible(selector, 8000);
  }

  async deleteIngredient(name) {
    logger.info(`Deleting ingredient: "${name}"`);
    try {
      const nameLower = name.toLowerCase();
      const selector = `//*[contains(translate(@content-desc, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz'), "${nameLower}")]`;
      const nameEl = await this.driver.$(selector);
      await nameEl.waitForDisplayed({ timeout: 8000 });
      const location = await nameEl.getLocation();
      const size = await nameEl.getSize();
      // Close button is at top-right corner of the card
      await this.driver.action('pointer')
        .move({ x: location.x + size.width + 50, y: location.y - 10 })
        .down()
        .up()
        .perform();
    } catch (e) {
      logger.error(`Failed to delete ingredient "${name}": ` + e.message);
    }
    await this.driver.pause(1000);
  }

  async clearAll() {
    logger.info('Clearing all ingredients from pantry...');
    try {
      const size = await this.driver.getWindowSize();
      const tapX = size.width - 60;
      const tapY = 130;
      logger.info(`Tapping clear sweep button at (${Math.round(tapX)}, ${Math.round(tapY)})`);
      await this.driver.action('pointer')
        .move({ x: Math.round(tapX), y: Math.round(tapY) })
        .down().up().perform();
    } catch (e) {
      logger.warn('Could not click clear all button: ' + e.message);
    }
    await this.waitForDisplayed(this.clearAllDialogBtn, 5000);
    await this.click(this.clearAllDialogBtn);
    await this.driver.pause(1000);
  }
}

module.exports = IngredientsPage;
