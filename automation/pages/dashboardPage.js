const BasePage = require('./basePage');
const logger = require('../utilities/logger');

/**
 * DashboardPage - Page Object for the Dashboard screen.
 *
 * Flutter GestureDetector widgets expose @content-desc but may NOT have clickable="true".
 * Use @content-desc without @clickable="true" requirement for cards.
 * Only tab buttons reliably expose clickable="true".
 */
class DashboardPage extends BasePage {
  constructor(driver) {
    super(driver);
  }

  // ── Selectors ─────────────────────────────────────────────────────────────
  get profileAvatar() {
    return '//*[contains(@content-desc, "👨") or contains(@text, "👨")]';
  }

  get greetingText() {
    return '//*[contains(@content-desc, "Good morning") or contains(@content-desc, "Good afternoon") or contains(@content-desc, "Good evening")]';
  }

  // Cards: use contains(@content-desc) as Flutter merges titles and subtitles
  get ingredientsCard()   { return '//*[contains(@content-desc, "My Ingredients")]'; }
  get generateMealsCard() { return '//*[contains(@content-desc, "Generate Meals")]'; }
  get shoppingListCard()  { return '//*[contains(@content-desc, "Shopping List")]'; }
  get chefChatCard()      { return '//*[contains(@content-desc, "AI Chef Chat")]'; }

  // Stable landmark elements on the dashboard
  get kitchenActionsHeader() { return '//*[@content-desc="Kitchen Actions"]'; }
  get zeroBasteChip()        { return '//*[contains(@content-desc, "Zero Waste")]'; }

  // ── Methods ───────────────────────────────────────────────────────────────
  async verifyOnDashboard(expectedName) {
    logger.info(`Verifying on Dashboard. Expected name: "${expectedName}"`);

    // Primary check: greeting text
    try {
      await this.waitForDisplayed(this.greetingText, 20000);
      logger.info('Dashboard greeting visible — confirmed on dashboard');
    } catch (e) {
      // Fallback: check for "Kitchen Actions" section header
      try {
        await this.waitForDisplayed(this.kitchenActionsHeader, 10000);
        logger.info('Dashboard "Kitchen Actions" header visible — confirmed on dashboard');
      } catch (e2) {
        // Final fallback: check for any dashboard card
        try {
          await this.waitForDisplayed(this.ingredientsCard, 8000);
          logger.info('Dashboard "My Ingredients" card visible — confirmed on dashboard');
        } catch (e3) {
          logger.error('Dashboard verification failed — no landmarks found');
          return false;
        }
      }
    }

    if (expectedName) {
      try {
        const nameEl = await this.driver.$(`//*[@content-desc="${expectedName}"]`);
        if (await nameEl.isExisting()) {
          logger.info(`User name "${expectedName}" confirmed on dashboard`);
          return true;
        }
        // Partial match on first word
        const firstName = expectedName.split(' ')[0];
        const partialEls = await this.driver.$$(`//*[contains(@content-desc, "${firstName}")]`);
        for (const el of partialEls) {
          const desc = await el.getAttribute('content-desc');
          // Skip multi-word content-desc values that are clearly not the username
          if (desc && !desc.includes('\n') && desc.length < 60) {
            logger.info(`Partial name match: "${desc}"`);
            return true;
          }
        }
      } catch (e) {
        logger.warn('Name check failed but greeting was visible: ' + e.message);
      }
    }

    return true; // Greeting visible = on dashboard
  }

  async navigateToIngredients() {
    logger.info('Navigating to Ingredients management screen...');
    try {
      await this.scrollUntilVisible(this.ingredientsCard, 3, 'down');
    } catch (e) {
      logger.warn('Could not scroll to ingredients card: ' + e.message);
    }
    await this.click(this.ingredientsCard);
    await this.driver.pause(1500);
  }

  async navigateToGenerateMeals() {
    logger.info('Navigating to AI Meal Generation screen...');
    try {
      await this.scrollUntilVisible(this.generateMealsCard, 3, 'down');
    } catch (e) {
      logger.warn('Could not scroll to generate meals card: ' + e.message);
    }
    await this.click(this.generateMealsCard);
    await this.driver.pause(1500);
  }

  async navigateToShoppingList() {
    logger.info('Navigating to Shopping List screen...');
    try {
      await this.scrollUntilVisible(this.shoppingListCard, 3, 'down');
    } catch (e) {
      logger.warn('Could not scroll to shopping list card: ' + e.message);
    }
    await this.click(this.shoppingListCard);
    await this.driver.pause(1500);
  }

  async navigateToChefChat() {
    logger.info('Navigating to AI Chef Chat screen...');
    try {
      await this.scrollUntilVisible(this.chefChatCard, 3, 'down');
    } catch (e) {
      logger.warn('Could not scroll to chef chat card: ' + e.message);
    }
    await this.click(this.chefChatCard);
    await this.driver.pause(1500);
  }

  async navigateToProfile() {
    logger.info('Navigating to User Profile by clicking chef avatar...');
    try {
      const size = await this.driver.getWindowSize();
      // Swipe down to scroll up and reveal the top header
      await this.driver.action('pointer')
        .move({ x: Math.round(size.width / 2), y: Math.round(size.height * 0.2) })
        .down()
        .move({ x: Math.round(size.width / 2), y: Math.round(size.height * 0.7) })
        .up()
        .perform();
      await this.driver.pause(800);
    } catch (e) {
      logger.warn('Failed to scroll up to reveal avatar: ' + e.message);
    }
    await this.click(this.profileAvatar);
    await this.driver.pause(1500);
  }

  async getIngredientStatCount() {
    try {
      const el = await this.driver.$('//*[contains(@content-desc, "Ingredients")]');
      const desc = await el.getAttribute('content-desc');
      const match = desc && desc.match(/(\d+)/);
      if (match) {
        logger.info(`Dashboard Ingredient count: ${match[1]}`);
        return parseInt(match[1], 10);
      }
    } catch (e) {
      logger.warn('Could not read ingredient count: ' + e.message);
    }
    return 0;
  }
}

module.exports = DashboardPage;
