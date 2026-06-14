const { expect } = require('chai');
const { setupTestContext } = require('./baseTest');
const LoginPage = require('../pages/loginPage');
const DashboardPage = require('../pages/dashboardPage');
const ProfilePage = require('../pages/profilePage');
const logger = require('../utilities/logger');

describe('User Profile Testing', function () {
  setupTestContext('Profile');

  let loginPage;
  let dashboardPage;
  let profilePage;
  const email = 'shared_chef@example.com';

  before(function () {
    loginPage = new LoginPage(this.driver);
    dashboardPage = new DashboardPage(this.driver);
    profilePage = new ProfilePage(this.driver);
  });

  it('1. Register and login to reach Dashboard', async function () {
    const onDash = await dashboardPage.verifyOnDashboard('Shared Chef');
    expect(onDash).to.be.true;
  });

  it('2. Navigate to User Profile screen', async function () {
    await dashboardPage.navigateToProfile();
    const isProfileOpen = await profilePage.isElementVisible('//*[@content-desc="Preferences"]', 8000);
    expect(isProfileOpen).to.be.true;
  });

  it('3. Edit user profile details', async function () {
    const size = await this.driver.getWindowSize();
    const tapX = size.width - 60;
    const tapY = 130;

    // Click edit button at top-right
    logger.info(`Tapping edit button at (${Math.round(tapX)}, ${Math.round(tapY)})`);
    await this.driver.action('pointer')
      .move({ x: Math.round(tapX), y: Math.round(tapY) })
      .down().up().perform();
    await this.driver.pause(1000);
    
    // Type new name in name input (it is the first text field on screen)
    let nameInput = await this.driver.$('//android.widget.EditText[1]');
    if (await nameInput.isExisting()) {
      await nameInput.setValue('Gordon Ramsey');
      await profilePage.hideKeyboard();
      await this.driver.pause(500);
    }
    
    // Click check icon to save
    logger.info(`Tapping save button at (${Math.round(tapX)}, ${Math.round(tapY)})`);
    await this.driver.action('pointer')
      .move({ x: Math.round(tapX), y: Math.round(tapY) })
      .down().up().perform();
    await this.driver.pause(2000);
    
    // Verify name update on profile screen
    const hasName = await profilePage.verifyProfileDetails('Gordon Ramsey', email);
    expect(hasName).to.be.true;

    // RESTORE name back to Shared Chef so subsequent tests are idempotent
    logger.info('Restoring profile name back to "Shared Chef"...');
    await this.driver.action('pointer')
      .move({ x: Math.round(tapX), y: Math.round(tapY) })
      .down().up().perform();
    await this.driver.pause(1000);

    nameInput = await this.driver.$('//android.widget.EditText[1]');
    if (await nameInput.isExisting()) {
      await nameInput.setValue('Shared Chef');
      await profilePage.hideKeyboard();
      await this.driver.pause(500);
    }

    await this.driver.action('pointer')
      .move({ x: Math.round(tapX), y: Math.round(tapY) })
      .down().up().perform();
    await this.driver.pause(2000);

    const restoredName = await profilePage.verifyProfileDetails('Shared Chef', email);
    expect(restoredName).to.be.true;
  });

  it('4. Toggle diet preferences', async function () {
    // Click "Vegetarian" chip
    const vegChip = await this.driver.$('//*[contains(@content-desc, "Vegetarian")]');
    if (await vegChip.isExisting()) {
      await vegChip.click();
      await this.driver.pause(800);
    }
    
    // Click "Gluten-Free" chip
    const gfChip = await this.driver.$('//*[contains(@content-desc, "Gluten-Free")]');
    if (await gfChip.isExisting()) {
      await gfChip.click();
      await this.driver.pause(800);
    }
  });

  it('5. Toggle allergy preferences', async function () {
    // Scroll down to expose allergies section if needed
    const size = await this.driver.getWindowSize();
    await this.driver.action('pointer')
      .move({ x: size.width / 2, y: size.height * 0.7 })
      .down()
      .move({ x: size.width / 2, y: size.height * 0.3 })
      .up()
      .perform();
    await this.driver.pause(800);

    // Click "Peanuts" chip
    const peanutsChip = await this.driver.$('//*[contains(@content-desc, "Peanuts")]');
    if (await peanutsChip.isExisting()) {
      await peanutsChip.click();
      await this.driver.pause(800);
    }
  });

  it('6. Switch between saved and history tabs', async function () {
    // Scroll up to expose tabs
    const size = await this.driver.getWindowSize();
    await this.driver.action('pointer')
      .move({ x: size.width / 2, y: size.height * 0.3 })
      .down()
      .move({ x: size.width / 2, y: size.height * 0.7 })
      .up()
      .perform();
    await this.driver.pause(800);

    // Click "Saved" tab
    const savedTab = await this.driver.$('//*[contains(@content-desc, "Saved") or contains(@text, "Saved")]');
    await savedTab.click();
    await this.driver.pause(1000);
    const hasSavedEmptyText = await this.driver.$('//*[contains(@content-desc, "No saved meals") or contains(@text, "No saved meals")]').isExisting();
    expect(hasSavedEmptyText).to.be.true;

    // Click "History" tab
    const historyTab = await this.driver.$('//*[contains(@content-desc, "History") or contains(@text, "History")]');
    await historyTab.click();
    await this.driver.pause(1000);
    const hasHistEmptyText = await this.driver.$('//*[contains(@content-desc, "No cooking history") or contains(@text, "No cooking history")]').isExisting();
    expect(hasHistEmptyText).to.be.true;
  });
});
