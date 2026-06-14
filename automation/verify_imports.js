const logger = require('./utilities/logger');
logger.info('Starting Framework Import Verification...');

try {
  // Load config
  const config = require('./config/appium.config');
  logger.info('✓ Appium Config Loaded Successfully.');

  // Load factory
  const DriverFactory = require('./drivers/driverFactory');
  logger.info('✓ Driver Factory Loaded Successfully.');

  // Load utilities
  const excelReporter = require('./utilities/excelReporter');
  const AppiumUtils = require('./utilities/appiumUtils');
  const GestureUtils = require('./utilities/gestureUtils');
  logger.info('✓ Utilities Loaded Successfully.');

  // Load POMs
  const BasePage = require('./pages/basePage');
  const LoginPage = require('./pages/loginPage');
  const DashboardPage = require('./pages/dashboardPage');
  const IngredientsPage = require('./pages/ingredientsPage');
  const MealGeneratorPage = require('./pages/mealGeneratorPage');
  const RecipeDetailPage = require('./pages/recipeDetailPage');
  const ProfilePage = require('./pages/profilePage');
  logger.info('✓ Page Object Models Loaded Successfully.');

  // Load Base Test hooks
  const baseTest = require('./tests/baseTest');
  logger.info('✓ Base Test Hooks Loaded Successfully.');

  logger.info('SUCCESS: All Appium automation framework files imported and resolved successfully!');
} catch (error) {
  logger.error('IMPORT ERROR: Failed to resolve one or more imports: ' + error.stack);
  process.exit(1);
}
