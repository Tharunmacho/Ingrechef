const { expect } = require('chai');
const { setupTestContext } = require('./baseTest');
const LoginPage = require('../pages/loginPage');
const DashboardPage = require('../pages/dashboardPage');
const IngredientsPage = require('../pages/ingredientsPage');
const MealGeneratorPage = require('../pages/mealGeneratorPage');
const RecipeDetailPage = require('../pages/recipeDetailPage');

describe('AI Meal Generation Testing', function () {
  setupTestContext('MealGen');

  let loginPage;
  let dashboardPage;
  let ingredientsPage;
  let mealGeneratorPage;
  let recipeDetailPage;

  before(function () {
    loginPage = new LoginPage(this.driver);
    dashboardPage = new DashboardPage(this.driver);
    ingredientsPage = new IngredientsPage(this.driver);
    mealGeneratorPage = new MealGeneratorPage(this.driver);
    recipeDetailPage = new RecipeDetailPage(this.driver);
  });

  it('1. Register and login to reach Dashboard', async function () {
    const onDash = await dashboardPage.verifyOnDashboard('Shared Chef');
    expect(onDash).to.be.true;
  });

  it('2. Generate meals with no ingredients', async function () {
    await dashboardPage.navigateToGenerateMeals();
    await mealGeneratorPage.triggerGeneration();

    // Verify empty state: "No meals found"
    const emptyState = await this.driver.$('//*[contains(@content-desc, "No meals") or contains(@content-desc, "Try Again")]');
    expect(await emptyState.isExisting()).to.be.true;

    // Go back to Dashboard
    await this.driver.back();
    await this.driver.pause(1000);
  });

  it('3. Add ingredients and generate meals successfully', async function () {
    this.timeout(120000);
    await dashboardPage.navigateToIngredients();
    await ingredientsPage.addIngredient('Pasta');
    await ingredientsPage.addIngredient('Chicken');
    await this.driver.back();
    await this.driver.pause(1000);

    await dashboardPage.navigateToGenerateMeals();
    await mealGeneratorPage.triggerGeneration();

    const firstRecipeBtn = await this.driver.$('//*[contains(@content-desc, "View Recipe") and @clickable="true"]');
    expect(await firstRecipeBtn.isExisting()).to.be.true;
  });

  it('4. Toggle sorting by calories', async function () {
    // Open sorting modal
    const sortBtn = await this.driver.$('//*[contains(@content-desc, "Time") or contains(@content-desc, "Calories") or contains(@content-desc, "sort")]');
    if (await sortBtn.isExisting()) {
      await sortBtn.click();
      await this.driver.pause(1000);
    }
    
    // Select Calories option in modal bottom sheet
    const calOption = await this.driver.$('//*[@content-desc="Calories" and @clickable="true"]');
    if (await calOption.isExisting()) {
      await calOption.click();
      await this.driver.pause(1200);
    }
  });

  it('5. Verify Recipe Detail Page tabs', async function () {
    await mealGeneratorPage.viewFirstRecipe();
    const isDetail = await recipeDetailPage.verifyOnRecipeDetail();
    expect(isDetail).to.be.true;

    // Switch to Ingredients tab
    const ingTab = await this.driver.$('//*[contains(@content-desc, "Ingredients") or contains(@text, "Ingredients")]');
    await ingTab.click();
    await this.driver.pause(1000);

    // Switch to Nutrition tab
    const nutTab = await this.driver.$('//*[contains(@content-desc, "Nutrition") or contains(@text, "Nutrition")]');
    await nutTab.click();
    await this.driver.pause(1000);
  });

  it('6. Start cooking mode and log meal complete', async function () {
    // Go back to Overview tab
    const ovTab = await this.driver.$('//*[contains(@content-desc, "Overview") or contains(@text, "Overview")]');
    await ovTab.click();
    await this.driver.pause(1000);

    // Click "Start Cooking Mode"
    const startCookingBtn = await this.driver.$('//*[contains(@content-desc, "Start Cooking")]');
    await startCookingBtn.click();
    await this.driver.pause(1200);

    // Walk through 5 steps of the recipe
    for (let i = 0; i < 5; i++) {
      const nextBtn = await this.driver.$('//*[contains(@content-desc, "Next Step") or contains(@content-desc, "Done")]');
      await nextBtn.click();
      await this.driver.pause(1000);
    }

    // After logging the cooked meal, we should be back on detail screen showing rating/steps
    const isDetailBack = await recipeDetailPage.verifyOnRecipeDetail();
    expect(isDetailBack).to.be.true;
  });
});
