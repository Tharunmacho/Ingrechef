const BasePage = require('./basePage');
const logger = require('../utilities/logger');

/**
 * ShoppingPage - Page Object for the Shopping List screen.
 */
class ShoppingPage extends BasePage {
  constructor(driver) {
    super(driver);
  }

  // ── Selectors ─────────────────────────────────────────────────────────────
  get myListTab()       { return '//*[contains(@content-desc, "My List") or contains(@text, "My List")]'; }
  get smartPicksTab()   { return '//*[contains(@content-desc, "Smart Picks") or contains(@text, "Smart Picks")]'; }
  get addItemFab()      { return '//*[contains(@content-desc, "Add Item")]'; }
  get itemInput()       { return '//android.widget.EditText'; }
  get addButton()       { return '//*[contains(@content-desc, "Add to List") or contains(@text, "Add to List")]'; }
  get clearCompletedBtn(){ return '//*[contains(@content-desc, "Clear completed")]'; }

  // ── Methods ───────────────────────────────────────────────────────────────
  async switchTab(tabName) {
    logger.info(`Switching to Shopping List tab: "${tabName}"`);
    if (tabName.toLowerCase() === 'my list') {
      await this.click(this.myListTab);
    } else {
      await this.click(this.smartPicksTab);
    }
    await this.driver.pause(1000);
  }

  async addCustomItem(name) {
    logger.info(`Adding custom shopping list item: "${name}"`);
    await this.click(this.addItemFab);
    await this.driver.pause(1000);

    const inputEl = await this.driver.$(this.itemInput);
    await inputEl.waitForDisplayed({ timeout: 5000 });
    await inputEl.setValue(name);
    await this.driver.pause(300);

    // Hide keyboard
    await this.hideKeyboard();
    await this.driver.pause(300);

    // Click Add to List button on the sheet (uses wait-based click)
    await this.click(this.addButton);
    await this.driver.pause(1500); // Wait for sheet to close and list to reload
  }

  async toggleItem(name) {
    logger.info(`Toggling shopping list item: "${name}"`);
    const nameLower = name.toLowerCase();
    const tileSelector = `//*[contains(translate(@content-desc, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz'), "${nameLower}")]`;
    await this.click(tileSelector);
    await this.driver.pause(1200);
  }

  async verifyItemExists(name) {
    logger.info(`Checking if shopping item "${name}" exists...`);
    const nameLower = name.toLowerCase();
    const tileSelector = `//*[contains(translate(@content-desc, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz'), "${nameLower}")]`;
    return await this.isElementVisible(tileSelector, 6000);
  }

  async addSmartPick(name) {
    logger.info(`Adding smart pick suggestion: "${name}"`);
    await this.switchTab('smart picks');

    // Robust XPath using ancestor-descendant pattern instead of following::
    const nameLower = name.toLowerCase();
    const specificBtnSelector = `//*[contains(translate(@content-desc, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz'), "${nameLower}")]/ancestor::*[.//*[contains(@content-desc, "Add") or contains(@text, "Add")]][1]//*[contains(@content-desc, "Add") or contains(@text, "Add")]`;
    try {
      await this.click(specificBtnSelector);
      logger.info(`Clicked Smart Pick add button specifically for "${name}"`);
    } catch (e) {
      logger.warn(`Could not click specific Smart Pick button: ${e.message}. Trying fallback...`);
      // Fallback: Click the first Add button
      const addBtns = await this.driver.$$('//*[contains(@content-desc, "Add") or contains(@text, "Add")]');
      if (addBtns.length > 0) {
        await addBtns[0].click();
        logger.info('Clicked a Smart Pick add button as fallback');
      } else {
        // Coordinate tap near the top suggestion
        const size = await this.driver.getWindowSize();
        const tapX = size.width * 0.85; // Far right side
        const tapY = size.height * 0.35; // Near the top suggestion
        logger.info(`Tapping smart pick add button at coordinate: (${Math.round(tapX)}, ${Math.round(tapY)})`);
        await this.driver.action('pointer')
          .move({ x: Math.round(tapX), y: Math.round(tapY) })
          .down().up().perform();
      }
    }
    await this.driver.pause(1500);
  }

  async clearCompleted() {
    logger.info('Clearing completed items...');
    try {
      await this.scrollUntilVisible(this.clearCompletedBtn, 2, 'down');
      await this.click(this.clearCompletedBtn);
      await this.driver.pause(1500);
    } catch (e) {
      logger.warn('Could not clear completed: ' + e.message);
    }
  }
}

module.exports = ShoppingPage;
