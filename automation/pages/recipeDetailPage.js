const BasePage = require('./basePage');
const logger = require('../utilities/logger');

/**
 * RecipeDetailPage - Page Object for the Meal Detail screen.
 *
 * MealDetailScreen has TabBar: Overview | Ingredients | Nutrition
 * These tab labels render as android.view.View with @content-desc.
 */
class RecipeDetailPage extends BasePage {
  constructor(driver) {
    super(driver);
  }

  // ── Methods ───────────────────────────────────────────────────────────────
  async verifyOnRecipeDetail() {
    logger.info('Verifying user is on Recipe Detail screen...');
    // Check for the tab bar labels or any distinctive content
    const indicators = [
      '//*[@content-desc="Overview"]',
      '//*[@content-desc="Ingredients"]',
      '//*[@content-desc="Nutrition"]',
      '//*[@content-desc="Recipe Steps"]',
      '//*[@content-desc="Rate this recipe"]',
      '//*[contains(@content-desc, "Start Cooking")]',
    ];
    for (const xpath of indicators) {
      if (await this.isElementVisible(xpath, 5000)) {
        logger.info(`Recipe detail confirmed via: ${xpath}`);
        return true;
      }
    }
    logger.warn('Could not confirm recipe detail screen');
    return false;
  }

  async favoriteMeal() {
    logger.info('Tapping Favorite/Save button on recipe detail screen...');
    try {
      const size = await this.driver.getWindowSize();
      // Tap heart icon (to the left of share icon on the far right)
      const tapX = size.width - 160;
      const tapY = 130;
      logger.info(`Tapping favorite button at (${Math.round(tapX)}, ${Math.round(tapY)})`);
      await this.driver.action('pointer')
        .move({ x: Math.round(tapX), y: Math.round(tapY) })
        .down().up().perform();
      await this.driver.pause(1500); // Wait for Elastic scale animation and API response
    } catch (e) {
      logger.warn('Failed to tap favorite button: ' + e.message);
    }
  }

  async goBack() {
    logger.info('Navigating back from recipe detail screen...');
    // Try content-desc back button (AppBar leading icon)
    try {
      const backs = await this.driver.$$('//*[contains(@content-desc, "back") or contains(@content-desc, "Back") or contains(@content-desc, "Navigate")]');
      if (backs.length > 0) {
        await backs[0].click();
        await this.driver.pause(1000);
        return;
      }
    } catch (e) {
      logger.debug('content-desc back not found: ' + e.message);
    }
    // Fallback to hardware back
    await this.driver.back();
    await this.driver.pause(1000);
  }
}

module.exports = RecipeDetailPage;
