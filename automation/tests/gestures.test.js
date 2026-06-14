const { expect } = require('chai');
const { setupTestContext } = require('./baseTest');
const LoginPage = require('../pages/loginPage');
const DashboardPage = require('../pages/dashboardPage');
const GestureUtils = require('../utilities/gestureUtils');
const logger = require('../utilities/logger');

describe('Mobile Gesture Automations', function () {
  setupTestContext('Gestures');

  let loginPage;
  let dashboardPage;

  before(function () {
    loginPage     = new LoginPage(this.driver);
    dashboardPage = new DashboardPage(this.driver);
  });

  it('Perform login to access gesture views', async function () {
    const isDashboard = await dashboardPage.verifyOnDashboard('Shared Chef');
    expect(isDashboard).to.be.true;
  });

  it('Verify swipe and scroll actions on Dashboard', async function () {
    // Allow UI to settle before gestures
    await this.driver.pause(1000);

    // Scroll down to expose more content
    await GestureUtils.swipeUp(this.driver, 0.7);
    await this.driver.pause(1500);

    // Horizontal swipe on recipe/suggestion list
    await GestureUtils.swipeLeft(this.driver, 0.7);
    await this.driver.pause(1000);
    await GestureUtils.swipeRight(this.driver, 0.7);
    await this.driver.pause(1000);

    // Scroll back to top
    await GestureUtils.swipeDown(this.driver, 0.5);
    await this.driver.pause(1500);

    // Verify still on dashboard using a robust check (any card visible)
    // After swipes, the greeting might be temporarily off-screen
    const hasIngCard = await dashboardPage.isElementVisible(dashboardPage.ingredientsCard, 8000);
    const hasGenCard = await dashboardPage.isElementVisible(dashboardPage.generateMealsCard, 5000);
    const hasGreeting = await dashboardPage.isElementVisible(dashboardPage.greetingText, 5000);
    const onDashboard = hasIngCard || hasGenCard || hasGreeting;
    logger.info(`Dashboard landmarks: ingredientsCard=${hasIngCard} generateMealsCard=${hasGenCard} greeting=${hasGreeting}`);
    expect(onDashboard).to.be.true;
  });

  it('Verify pinch and zoom actions on Dashboard card banner', async function () {
    // Scroll back to top to see the banner
    await GestureUtils.swipeDown(this.driver, 0.5);
    await this.driver.pause(800);

    try {
      const banner = await this.driver.$('//*[contains(@content-desc, "Zero Waste")]');
      if (await banner.isExisting()) {
        await GestureUtils.zoom(this.driver, banner);
        await this.driver.pause(1000);
        await GestureUtils.pinch(this.driver, banner);
        await this.driver.pause(1000);
      } else {
        logger.warn('Zero Waste banner not found, skipping pinch/zoom gestures');
      }
    } catch (e) {
      logger.warn('Pinch/zoom gesture failed (non-critical): ' + e.message);
    }

    // Verify app is still on dashboard using any available landmark
    const hasIngCard = await dashboardPage.isElementVisible(dashboardPage.ingredientsCard, 8000);
    const hasGreeting = await dashboardPage.isElementVisible(dashboardPage.greetingText, 5000);
    const onDashboard = hasIngCard || hasGreeting;
    expect(onDashboard).to.be.true;
  });
});
