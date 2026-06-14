const { expect } = require('chai');
const { setupTestContext } = require('./baseTest');
const LoginPage = require('../pages/loginPage');
const DashboardPage = require('../pages/dashboardPage');
const IngredientsPage = require('../pages/ingredientsPage');
const logger = require('../utilities/logger');

describe('Ingredients Management Testing', function () {
  setupTestContext('Ingredients');

  let loginPage;
  let dashboardPage;
  let ingredientsPage;

  before(function () {
    loginPage = new LoginPage(this.driver);
    dashboardPage = new DashboardPage(this.driver);
    ingredientsPage = new IngredientsPage(this.driver);
  });

  it('1. Verify Dashboard landing', async function () {
    const onDash = await dashboardPage.verifyOnDashboard('Shared Chef');
    expect(onDash).to.be.true;
  });

  it('2. Navigate to Ingredients screen', async function () {
    await dashboardPage.navigateToIngredients();
    const titleVisible = await ingredientsPage.isElementVisible('//*[@content-desc="My Ingredients"]', 8000);
    expect(titleVisible).to.be.true;
  });

  it('3. Add new ingredient to pantry', async function () {
    const ingName = 'Chicken';
    await ingredientsPage.addIngredient(ingName);
    const exists = await ingredientsPage.verifyIngredientExists(ingName);
    expect(exists).to.be.true;
  });

  it('4. Filter pantry ingredients by category', async function () {
    // Click "Protein" category chip
    const proteinChip = await this.driver.$('//*[contains(@content-desc, "Protein") and @clickable="true"]');
    if (await proteinChip.isExisting()) {
      await proteinChip.click();
      await this.driver.pause(1000);
      logger.info('Clicked Protein category chip');
    }
    // Chicken is protein, so it should still be visible
    const exists = await ingredientsPage.verifyIngredientExists('Chicken');
    expect(exists).to.be.true;

    // Click "Grains" category chip (should filter out Chicken)
    const grainsChip = await this.driver.$('//*[contains(@content-desc, "Grains") and @clickable="true"]');
    if (await grainsChip.isExisting()) {
      await grainsChip.click();
      await this.driver.pause(1000);
      logger.info('Clicked Grains category chip');
    }
  });

  it('5. Delete a specific ingredient from pantry', async function () {
    // Reset to "All" category chip
    const allChip = await this.driver.$('//*[contains(@content-desc, "All") and @clickable="true"]');
    if (await allChip.isExisting()) {
      await allChip.click();
      await this.driver.pause(1000);
    }
    
    // Add Onion and delete it
    const ingToDelete = 'Onion';
    await ingredientsPage.addIngredient(ingToDelete);
    let exists = await ingredientsPage.verifyIngredientExists(ingToDelete);
    expect(exists).to.be.true;

    await ingredientsPage.deleteIngredient(ingToDelete);
    exists = await ingredientsPage.verifyIngredientExists(ingToDelete);
    expect(exists).to.be.false;
  });

  it('6. Clear all ingredients from pantry', async function () {
    // Add Garlic first
    await ingredientsPage.addIngredient('Garlic');
    
    // Clear all
    await ingredientsPage.clearAll();
    
    // Verify empty state text
    const emptyStateVisible = await ingredientsPage.isElementVisible('//*[contains(@content-desc, "No ingredients")]', 5000);
    expect(emptyStateVisible).to.be.true;
  });
});
