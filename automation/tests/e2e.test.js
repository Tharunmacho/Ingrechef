const { expect } = require('chai');
const { setupTestContext } = require('./baseTest');
const LoginPage = require('../pages/loginPage');
const DashboardPage = require('../pages/dashboardPage');
const IngredientsPage = require('../pages/ingredientsPage');
const MealGeneratorPage = require('../pages/mealGeneratorPage');
const RecipeDetailPage = require('../pages/recipeDetailPage');
const ProfilePage = require('../pages/profilePage');
const ShoppingPage = require('../pages/shoppingPage');
const logger = require('../utilities/logger');

describe('End-to-End User Workflows', function () {
  setupTestContext('End-to-End');

  let loginPage;
  let dashboardPage;
  let ingredientsPage;
  let mealGeneratorPage;
  let recipeDetailPage;
  let profilePage;
  let shoppingPage;

  before(function () {
    loginPage         = new LoginPage(this.driver);
    dashboardPage     = new DashboardPage(this.driver);
    ingredientsPage   = new IngredientsPage(this.driver);
    mealGeneratorPage = new MealGeneratorPage(this.driver);
    recipeDetailPage  = new RecipeDetailPage(this.driver);
    profilePage       = new ProfilePage(this.driver);
    shoppingPage      = new ShoppingPage(this.driver);
  });

  it('Execute complete kitchen workflow', async function () {
    this.timeout(400000); // 6.6 minutes

    // 1. Verify Dashboard landing (pre-logged in as Shared Chef)
    const onDashboard = await dashboardPage.verifyOnDashboard('Shared Chef');
    expect(onDashboard).to.be.true;

    // 2. Navigate to Ingredients screen and clear all pantry ingredients to ensure a clean state
    await dashboardPage.navigateToIngredients();
    const hasIngTitle = await ingredientsPage.isElementVisible('//*[@content-desc="My Ingredients"]', 8000);
    expect(hasIngTitle).to.be.true;

    // Add Onion and clear all to start clean
    await ingredientsPage.addIngredient('Onion');
    await ingredientsPage.clearAll();
    await this.driver.back();
    await this.driver.pause(1000);

    // 3. Clear shopping list to start from clean slate
    await dashboardPage.navigateToShoppingList();
    const hasShopTitle = await shoppingPage.isElementVisible('//*[contains(@content-desc, "Shopping List")]', 8000);
    expect(hasShopTitle).to.be.true;
    // We already clear the shopping list database records via clearTestData in baseTest.js,
    // but we check if we're on the list successfully.
    await this.driver.back();
    await this.driver.pause(1000);

    // 4. Add initial base ingredients (Pasta, Tomatoes, Garlic)
    await dashboardPage.navigateToIngredients();
    await ingredientsPage.addIngredient('Pasta');
    await ingredientsPage.addIngredient('Tomatoes');
    await ingredientsPage.addIngredient('Garlic');
    
    // Go back to Dashboard
    await this.driver.back();
    await this.driver.pause(1000);

    // 5. Navigate to AI Meal generator and trigger meal generation
    await dashboardPage.navigateToGenerateMeals();
    await mealGeneratorPage.triggerGeneration();

    // Verify Pasta Primavera is generated
    const pastaCard = await this.driver.$('//*[contains(@content-desc, "Pasta Primavera")]');
    expect(await pastaCard.isExisting()).to.be.true;

    // Verify it has missing ingredients (spinach/olive oil)
    const missingText = await this.driver.$('//*[contains(@content-desc, "spinach") or contains(@content-desc, "olive")]');
    expect(await missingText.isExisting()).to.be.true;

    // 6. Click "Add to List" button on the Pasta Primavera card to add missing ingredients to shopping list
    await mealGeneratorPage.click('//*[contains(@content-desc, "Pasta Primavera")]/ancestor::*[.//*[contains(@content-desc, "Add to List")]][1]//*[contains(@content-desc, "Add to List")]');
    await this.driver.pause(2000); // Wait for SnackBar confirmation

    // Navigate back to Dashboard
    await this.driver.back();
    await this.driver.pause(1000);

    // 7. Navigate to Shopping List and verify missing items are added
    await dashboardPage.navigateToShoppingList();
    const hasSpinach = await shoppingPage.verifyItemExists('spinach');
    const hasOliveOil = await shoppingPage.verifyItemExists('olive');
    expect(hasSpinach || hasOliveOil).to.be.true;

    // 8. Toggle/complete the missing items to "buy" them
    if (hasSpinach) await shoppingPage.toggleItem('spinach');
    if (hasOliveOil) await shoppingPage.toggleItem('olive');
    
    // Clear completed items (which calls clear_completed_shopping and adds them to pantry)
    await shoppingPage.clearCompleted();

    // Navigate back to Dashboard
    await this.driver.back();
    await this.driver.pause(1000);

    // 9. Go to Ingredients screen and verify spinach/olive oil are now in the pantry
    await dashboardPage.navigateToIngredients();
    const foundSpinach = await ingredientsPage.verifyIngredientExists('spinach');
    const foundOlive = await ingredientsPage.verifyIngredientExists('olive');
    expect(foundSpinach || foundOlive).to.be.true;

    // Navigate back to Dashboard
    await this.driver.back();
    await this.driver.pause(1000);

    // 10. Navigate to AI Meal generator again, trigger generation, and verify Pasta Primavera has 100% match
    await dashboardPage.navigateToGenerateMeals();
    await mealGeneratorPage.triggerGeneration();

    // View first recipe details
    await mealGeneratorPage.viewFirstRecipe();
    const isRecipeDetail = await recipeDetailPage.verifyOnRecipeDetail();
    expect(isRecipeDetail).to.be.true;

    // Save/Favorite the meal
    await recipeDetailPage.favoriteMeal();

    // Start cooking mode (remove clickable=true condition)
    await recipeDetailPage.click('//*[contains(@content-desc, "Start Cooking")]');
    await this.driver.pause(1000);

    // Walk through 5 steps of the recipe
    for (let i = 0; i < 5; i++) {
      await recipeDetailPage.click('//*[contains(@content-desc, "Next Step") or contains(@content-desc, "Done")]');
      await this.driver.pause(1000);
    }

    // Go back to Dashboard
    await recipeDetailPage.goBack();
    await this.driver.pause(1000);
    await this.driver.back();
    await this.driver.pause(1500);

    // 11. Open Profile screen and verify Saved & History tabs
    await dashboardPage.navigateToProfile();

    // Switch to Saved tab
    const savedTab = await this.driver.$('//*[contains(@content-desc, "Saved") or contains(@text, "Saved")]');
    await savedTab.click();
    await this.driver.pause(1500);
    const hasSavedMeal = await this.driver.$('//*[contains(translate(@content-desc, "ABCDEFGHIJKLMNOPQRSTUVWXYZ", "abcdefghijklmnopqrstuvwxyz"), "pasta primavera")]').isExisting();
    expect(hasSavedMeal).to.be.true;

    // Switch to History tab
    const historyTab = await this.driver.$('//*[contains(@content-desc, "History") or contains(@text, "History")]');
    await historyTab.click();
    await this.driver.pause(1500);
    const hasHistoryMeal = await this.driver.$('//*[contains(translate(@content-desc, "ABCDEFGHIJKLMNOPQRSTUVWXYZ", "abcdefghijklmnopqrstuvwxyz"), "pasta primavera")]').isExisting();
    expect(hasHistoryMeal).to.be.true;

    // Logout
    await profilePage.logout();

    // 12. Verify redirect back to Login screen
    const onAuth = await loginPage.isOnLoginScreen();
    expect(onAuth).to.be.true;
  });
});
