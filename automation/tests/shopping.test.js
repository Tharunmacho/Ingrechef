const { expect } = require('chai');
const { setupTestContext } = require('./baseTest');
const LoginPage = require('../pages/loginPage');
const DashboardPage = require('../pages/dashboardPage');
const ShoppingPage = require('../pages/shoppingPage');

describe('Shopping List Testing', function () {
  setupTestContext('Shopping');

  let loginPage;
  let dashboardPage;
  let shoppingPage;

  before(function () {
    loginPage = new LoginPage(this.driver);
    dashboardPage = new DashboardPage(this.driver);
    shoppingPage = new ShoppingPage(this.driver);
  });

  it('1. Verify Dashboard landing', async function () {
    const onDash = await dashboardPage.verifyOnDashboard('Shared Chef');
    expect(onDash).to.be.true;
  });

  it('2. Navigate to Shopping List screen', async function () {
    await dashboardPage.navigateToShoppingList();
    const titleVisible = await shoppingPage.isElementVisible('//*[@content-desc="Shopping List"]', 8000);
    expect(titleVisible).to.be.true;
  });

  it('3. Add custom item to shopping list', async function () {
    const itemName = 'Apples';
    await shoppingPage.addCustomItem(itemName);
    const exists = await shoppingPage.verifyItemExists(itemName);
    expect(exists).to.be.true;
  });

  it('4. Toggle item as completed', async function () {
    const itemName = 'Apples';
    await shoppingPage.toggleItem(itemName);
    // Toggling checked shows lineThrough and styling changes in Flutter
    // Check that we can still view the progress bar or the item is present
    const exists = await shoppingPage.verifyItemExists(itemName);
    expect(exists).to.be.true;
  });

  it('5. Add item from Smart Picks tab', async function () {
    // Switch to Smart Picks and add Lemon
    await shoppingPage.addSmartPick('Lemon');
    // It redirects back to tab 0
    await this.driver.pause(1000);
    const exists = await shoppingPage.verifyItemExists('Lemon');
    expect(exists).to.be.true;
  });

  it('6. Clear completed items from shopping list', async function () {
    // Clear completed (Apples is checked, so it should be cleared)
    await shoppingPage.clearCompleted();
    const applesExists = await shoppingPage.verifyItemExists('Apples');
    expect(applesExists).to.be.false;
  });
});
