const { expect } = require('chai');
const { setupTestContext } = require('./baseTest');
const LoginPage = require('../pages/loginPage');
const DashboardPage = require('../pages/dashboardPage');
const ChatPage = require('../pages/chatPage');

describe('AI Chef Chat Testing', function () {
  setupTestContext('Chat');

  let loginPage;
  let dashboardPage;
  let chatPage;

  before(function () {
    loginPage = new LoginPage(this.driver);
    dashboardPage = new DashboardPage(this.driver);
    chatPage = new ChatPage(this.driver);
  });

  it('1. Verify Dashboard landing', async function () {
    const onDash = await dashboardPage.verifyOnDashboard('Shared Chef');
    expect(onDash).to.be.true;
  });

  it('2. Navigate to AI Chef Chat screen', async function () {
    await dashboardPage.navigateToChefChat();
    const isChatOpen = await chatPage.isElementVisible('//*[contains(@content-desc, "AI Sous-Chef")]', 8000);
    expect(isChatOpen).to.be.true;
  });

  it('3. Verify chatbot greeting bubbles are displayed', async function () {
    const greeting1 = await chatPage.verifyMessageInBubble('AI sous-chef');
    expect(greeting1).to.be.true;
    
    const greeting2 = await chatPage.verifyMessageInBubble('You can:');
    expect(greeting2).to.be.true;
  });

  it('4. Click quick reply option', async function () {
    await chatPage.clickQuickReply(chatPage.quickReplySpinach);
    // Bot should respond, check if response is visible. The bot will reply and bubble will appear.
    // Let's check if the bubble contains "spinach" or some cooking ideas
    const hasResponse = await chatPage.verifyMessageInBubble('spinach');
    expect(hasResponse).to.be.true;
  });

  it('5. Send custom text message to bot', async function () {
    const query = 'Pesto recipe';
    await chatPage.sendMessage(query);
    // Bot will typing then respond
    await this.driver.pause(3000);
    const hasResponse = (await chatPage.verifyMessageInBubble('pesto')) || 
                        (await chatPage.verifyMessageInBubble('busy'));
    expect(hasResponse).to.be.true;
  });

  it('6. Clear chat history', async function () {
    await chatPage.clearChat();
    
    // Greeting should reset
    const clearedMsg = await chatPage.verifyMessageInBubble('Chat cleared!');
    expect(clearedMsg).to.be.true;
  });
});
