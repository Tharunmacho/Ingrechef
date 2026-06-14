const BasePage = require('./basePage');
const logger = require('../utilities/logger');

/**
 * MealGeneratorPage - Page Object for the AI Meal Generation screen.
 *
 * Flutter views use @content-desc (not @text).
 * - "Generate My Meals" button: android.view.View @content-desc="Generate My Meals" or contains it
 * - "View Recipe" button: ElevatedButton may expose content-desc or text
 */
class MealGeneratorPage extends BasePage {
  constructor(driver) {
    super(driver);
  }

  // ── Selectors ─────────────────────────────────────────────────────────────
  get generateMyMealsBtn() {
    return '//*[contains(@content-desc, "Generate My Meals") and @clickable="true"]';
  }
  get viewRecipeBtn() {
    return '//*[contains(@content-desc, "View Recipe") and @clickable="true"]';
  }

  // ── Methods ───────────────────────────────────────────────────────────────
  async triggerGeneration() {
    logger.info('Clicking "Generate My Meals" button...');
    await this.click(this.generateMyMealsBtn);

    logger.info('Waiting for AI generation to complete (up to 60s)...');
    // Wait for results: "View Recipe" button (success) or "Try Again" / "No meals found" (empty)
    const deadline = Date.now() + 60000;
    while (Date.now() < deadline) {
      const hasViewRecipe = await this.isElementVisible(this.viewRecipeBtn, 2000);
      if (hasViewRecipe) {
        logger.info('Meal generation complete — "View Recipe" button found');
        return;
      }
      const hasEmpty = await this.isElementVisible('//*[contains(@content-desc, "No meals") or contains(@content-desc, "Try Again")]', 1000);
      if (hasEmpty) {
        logger.warn('Meal generation returned empty results');
        return;
      }
      await this.driver.pause(2000);
    }
    logger.warn('Meal generation timed out — proceeding');
  }

  async viewFirstRecipe() {
    logger.info('Opening the first generated meal recipe detail...');
    const els = await this.driver.$$('//*[contains(@content-desc, "View Recipe") and @clickable="true"]');
    if (els.length === 0) {
      throw new Error('No "View Recipe" button found on meal generation results screen');
    }
    await els[0].click();
    await this.driver.pause(1500);
  }
}

module.exports = MealGeneratorPage;
