const BasePage = require('./basePage');
const logger = require('../utilities/logger');

/**
 * ChatPage - Page Object for the AI Chef Chat screen.
 */
class ChatPage extends BasePage {
  constructor(driver) {
    super(driver);
  }

  // ── Selectors ─────────────────────────────────────────────────────────────
  get chatInput()       { return '//android.widget.EditText'; }
  get clearChatBtn()    { return '//android.widget.Button[contains(@content-desc, "clear") or contains(@content-desc, "Clear")]'; }
  get quickReplySpinach() { return '//*[contains(@content-desc, "spinach") or contains(@content-desc, "Spinach")]'; }
  get quickReplyMeals()   { return '//*[contains(@content-desc, "15-min") or contains(@content-desc, "meals")]'; }

  // ── Methods ───────────────────────────────────────────────────────────────
  async sendMessage(message) {
    logger.info(`Sending message in chat: "${message}"`);
    const inputEl = await this.driver.$(this.chatInput);
    await inputEl.waitForDisplayed({ timeout: 5000 });
    await inputEl.click();
    await inputEl.setValue(message);
    await this.driver.pause(300);

    // Try to click send by coordinate (to the right of the input field)
    const location = await inputEl.getLocation();
    const size = await inputEl.getSize();
    const tapX = location.x + size.width + 35;
    const tapY = location.y + size.height / 2;
    logger.info(`Tapping send button at coordinate: (${Math.round(tapX)}, ${Math.round(tapY)})`);
    
    // Tap send
    await this.driver.action('pointer')
      .move({ x: Math.round(tapX), y: Math.round(tapY) })
      .down().up().perform();
      
    await this.driver.pause(2000); // Wait for response
  }

  async clickQuickReply(replySelector) {
    logger.info('Clicking quick reply option...');
    await this.click(replySelector);
    await this.driver.pause(3000); // Wait for bot typing and response
  }

  async verifyMessageInBubble(text) {
    logger.info(`Checking if chat bubbles contain text: "${text}"`);
    const bubbleSelector = `//*[contains(@content-desc, "${text}")]`;
    return await this.isElementVisible(bubbleSelector, 8000);
  }

  async clearChat() {
    logger.info('Clearing chat history...');
    // The clear icon is in AppBar actions
    const clearBtn = await this.driver.$(this.clearChatBtn);
    if (await clearBtn.isExisting()) {
      await clearBtn.click();
    } else {
      // Coordinate tap at top right of screen
      const size = await this.driver.getWindowSize();
      const tapX = size.width - 60;
      const tapY = 130; // Approx y position of AppBar action buttons
      logger.info(`Tapping clear button at coordinate: (${Math.round(tapX)}, ${Math.round(tapY)})`);
      await this.driver.action('pointer')
        .move({ x: Math.round(tapX), y: Math.round(tapY) })
        .down().up().perform();
    }
    await this.driver.pause(1000);
  }
}

module.exports = ChatPage;
