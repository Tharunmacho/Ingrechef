const DriverFactory = require('../drivers/driverFactory');
const excelReporter = require('../utilities/excelReporter');
const logger = require('../utilities/logger');
const AppiumUtils = require('../utilities/appiumUtils');
const LoginPage = require('../pages/loginPage');
const DashboardPage = require('../pages/dashboardPage');

// Keep track of active driver sessions globally
let driverInstance = null;
let globalSuiteStartTime = null;

/**
 * Waits for the Login Screen to be ready (past splash screen).
 * Polls until at least one EditText is enabled.
 */
async function waitForLoginScreen(driver, timeoutMs = 30000) {
  logger.info('Waiting for Login Screen to load (splash screen ~3s)...');
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    try {
      const edits = await driver.$$('//android.widget.EditText');
      if (edits.length > 0) {
        const enabled = await edits[0].getAttribute('enabled');
        if (enabled === 'true') {
          logger.info('Login Screen is ready. Found EditText elements.');
          return true;
        }
      }
    } catch (_) {}
    await driver.pause(500);
  }
  logger.warn('Login Screen did not appear within timeout — proceeding anyway.');
  return false;
}

/**
 * Resets the app to the Login Screen at the start of each test module.
 * Strategy: terminate + activate the app (no reinstall), then wait for login screen.
 * This ensures each module starts from a clean, known state.
 */
async function resetToLoginScreen(driver) {
  logger.info('Resetting app to Login Screen for clean module start...');
  try {
    await driver.terminateApp('com.example.ingrechef');
    await driver.pause(1000);
    await driver.activateApp('com.example.ingrechef');
    logger.info('App restarted. Waiting for Login Screen...');
    await waitForLoginScreen(driver, 25000);
  } catch (e) {
    logger.warn('App reset failed, trying background/foreground: ' + e.message);
    try {
      await driver.background(1);
      await driver.activateApp('com.example.ingrechef');
      await waitForLoginScreen(driver, 20000);
    } catch (e2) {
      logger.warn('All reset strategies failed, proceeding: ' + e2.message);
    }
  }
}

/**
 * Perform direct login for a shared user account. If it doesn't exist, sign it up first.
 */
async function loginOrCreateUser(driver) {
  const loginPage = new LoginPage(driver);
  const dashboardPage = new DashboardPage(driver);
  
  const email = 'shared_chef@example.com';
  const password = 'Password123!';
  const name = 'Shared Chef';
  
  logger.info(`Attempting direct login for ${email}...`);
  await loginPage.switchToSignIn();
  await loginPage.fillSignInForm(email, password);
  await loginPage.clickSubmit();
  await driver.pause(3000);
  
  const loggedIn = await dashboardPage.verifyOnDashboard(name);
  if (loggedIn) {
    logger.info('Direct login successful!');
    return true;
  }
  
  logger.info('Direct login failed. Account might not exist. Attempting registration...');
  try {
    await driver.terminateApp('com.example.ingrechef');
    await driver.pause(500);
    await driver.activateApp('com.example.ingrechef');
    await waitForLoginScreen(driver, 20000);
  } catch (e) {
    logger.warn('Failed to restart app during signup retry: ' + e.message);
  }
  
  await loginPage.switchToSignUp();
  await loginPage.fillSignUpForm(name, email, '9876543210', password, password);
  await loginPage.clickSubmit();
  await driver.pause(4000);
  
  logger.info('Registration submitted. Logging in...');
  await loginPage.switchToSignIn();
  await loginPage.fillSignInForm(email, password);
  await loginPage.clickSubmit();
  await driver.pause(3000);
  
  const success = await dashboardPage.verifyOnDashboard(name);
  if (!success) {
    throw new Error('Failed to login after registration!');
  }
  return true;
}

async function ensureLoggedOut(driver) {
  const loginPage = new LoginPage(driver);
  const dashboardPage = new DashboardPage(driver);
  const ProfilePage = require('../pages/profilePage');
  const profilePage = new ProfilePage(driver);

  logger.info('Ensuring user is logged out...');
  // Check if we are on the login screen first
  const onLogin = await loginPage.isOnLoginScreen();
  if (onLogin) {
    logger.info('Already on Login Screen.');
    return;
  }

  // If not, check if dashboard is visible and log out
  try {
    const avatar = await driver.$(dashboardPage.profileAvatar);
    if (await avatar.isExisting()) {
      logger.info('User is logged in. Navigating to profile to log out...');
      await dashboardPage.navigateToProfile();
      await profilePage.logout();
      logger.info('Logged out successfully.');
      return;
    }
  } catch (e) {
    logger.warn('Failed checking dashboard/logging out: ' + e.message);
  }
}


async function ensureOnDashboard(driver) {
  const dashboardPage = new DashboardPage(driver);
  const loginPage = new LoginPage(driver);

  logger.info('Ensuring app is on the Dashboard...');
  
  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      const greeting = await driver.$(dashboardPage.greetingText);
      const ingCard = await driver.$(dashboardPage.ingredientsCard);
      const onDash = (await greeting.isExisting() && await greeting.isDisplayed()) || 
                     (await ingCard.isExisting() && await ingCard.isDisplayed());
      if (onDash) {
        logger.info('Confirmed on Dashboard.');
        return;
      }
    } catch (_) {}

    try {
      const onLogin = await loginPage.isOnLoginScreen();
      if (onLogin) {
        logger.info('App is on Login Screen. Logging in...');
        await loginOrCreateUser(driver);
        return;
      }
    } catch (_) {}

    logger.info('Not on Dashboard. Pressing back to return to Dashboard...');
    try {
      await driver.back();
    } catch (err) {
      logger.warn('driver.back() failed: ' + err.message);
    }
    await driver.pause(1500);
  }
}

async function clearTestData(email) {
  logger.info(`Clearing all backend user data for ${email}...`);
  try {
    if (typeof fetch === 'function') {
      const res = await fetch('http://localhost:5000/clear_user_data', {
        method: 'DELETE',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ user_email: email })
      });
      const data = await res.json();
      logger.info(`Backend user data cleared via fetch: ${JSON.stringify(data)}`);
      return;
    }
    
    // Fallback to http request
    const http = require('http');
    const postData = JSON.stringify({ user_email: email });
    const options = {
      hostname: 'localhost',
      port: 5000,
      path: '/clear_user_data',
      method: 'DELETE',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(postData)
      }
    };
    
    await new Promise((resolve, reject) => {
      const req = http.request(options, (res) => {
        let body = '';
        res.on('data', (chunk) => body += chunk);
        res.on('end', () => {
          logger.info(`Backend user data cleared via http: ${body}`);
          resolve();
        });
      });
      req.on('error', (e) => {
        logger.warn(`HTTP request error: ${e.message}`);
        resolve();
      });
      req.write(postData);
      req.end();
    });
  } catch (e) {
    logger.warn(`Failed to clear test user data: ${e.message}`);
  }
}

function setupTestContext(moduleName) {
  let scenarioStartTime;
  let testIdCounter = 1;

  before(async function () {
    this.timeout(180000);
    logger.info(`=== Starting Module: ${moduleName} ===`);

    if (!globalSuiteStartTime) {
      globalSuiteStartTime = Date.now();
    }

    const launchStart = Date.now();
    if (!driverInstance) {
      // First module: create driver fresh
      driverInstance = await DriverFactory.createDriver();
      await waitForLoginScreen(driverInstance);

      const caps = driverInstance.capabilities;
      const deviceName = caps.deviceName || caps['appium:deviceName'] || caps.udid || 'Android Device';
      const androidVersion = caps.platformVersion || caps['appium:platformVersion'] || '16';
      excelReporter.setDeviceInfo(deviceName, androidVersion);

      const launchDuration = Date.now() - launchStart;
      logger.info(`App Launch Time: ${(launchDuration / 1000).toFixed(2)}s`);
      excelReporter.addExecutionLog(new Date(), 'Global Launch', 'App Launch', 'Success',
        `Launch Time: ${(launchDuration / 1000).toFixed(2)}s`);
    } else {
      // Subsequent modules: restart app to get back to Login Screen cleanly
      await resetToLoginScreen(driverInstance);
    }

    if (moduleName === 'Authentication' || moduleName === 'Form Validation') {
      await ensureLoggedOut(driverInstance);
    } else {
      await loginOrCreateUser(driverInstance);
      await clearTestData('shared_chef@example.com');
    }

    this.driver = driverInstance;
  });

  beforeEach(async function () {
    scenarioStartTime = Date.now();
    const testTitle = this.currentTest.title;
    logger.info(`--- Starting Scenario: "${testTitle}" ---`);
    excelReporter.addExecutionLog(new Date(scenarioStartTime), testTitle, 'Scenario Start', 'Started',
      `Running on device: ${excelReporter.summaryData.deviceName}`);

    if (moduleName !== 'Authentication' && moduleName !== 'Form Validation' && driverInstance) {
      await ensureOnDashboard(driverInstance);
    }
  });

  afterEach(async function () {
    const test = this.currentTest;
    const duration = Date.now() - scenarioStartTime;
    const testId = `${moduleName.substring(0, 3).toUpperCase()}-${String(testIdCounter++).padStart(3, '0')}`;
    const status = test.state === 'passed' ? 'Passed' : (test.state === 'failed' ? 'Failed' : 'Skipped');

    logger.info(`--- Completed Scenario: "${test.title}" | Status: ${status} | Duration: ${(duration / 1000).toFixed(2)}s ---`);

    excelReporter.addTestCase(testId, moduleName, test.title,
      excelReporter.summaryData.deviceName, status,
      new Date(scenarioStartTime), new Date(Date.now()), duration);

    excelReporter.addExecutionLog(new Date(), test.title, 'Scenario Complete', status,
      `Duration: ${(duration / 1000).toFixed(2)}s`);

    if (status === 'Failed') {
      const errorMsg = test.err ? test.err.message : 'Unknown failure';
      const stackTrace = test.err ? test.err.stack : '';
      logger.error(`Test Scenario Failed: "${test.title}". Reason: ${errorMsg}\nStack: ${stackTrace}`);

      let screenshotPath = 'N/A';
      let logsPath = 'N/A';
      let currentActivity = 'Unknown';

      if (this.driver) {
        try {
          screenshotPath = await AppiumUtils.captureScreenshot(this.driver, test.title) || 'N/A';
          logsPath = await AppiumUtils.captureDeviceLogs(this.driver, test.title) || 'N/A';
          currentActivity = await AppiumUtils.getCurrentActivity(this.driver);
        } catch (e) {
          logger.error('Error executing failure capture actions: ' + e.message);
        }
      }

      excelReporter.addFailedTest(test.title, errorMsg, screenshotPath,
        excelReporter.summaryData.deviceName, excelReporter.summaryData.androidVersion, currentActivity);

      excelReporter.addExecutionLog(new Date(), test.title, 'Diagnostics Captured', 'Failure',
        `Screenshot: ${screenshotPath} | Logcat: ${logsPath} | Activity: ${currentActivity}`);
    }
  });

  after(async function () {
    logger.info(`=== Finished Module: ${moduleName} ===`);
    const totalDuration = Date.now() - globalSuiteStartTime;
    excelReporter.setDuration(totalDuration);
    await excelReporter.generateReport();
    logger.info(`Excel E2E Report successfully updated at: ${excelReporter.reportPath}`);
  });
}

// Global teardown hook
if (typeof after === 'function') {
  after(async function () {
    if (driverInstance) {
      logger.info('Closing all Appium driver sessions...');
      try {
        await driverInstance.deleteSession();
      } catch (e) {
        logger.warn('Error closing Appium driver session: ' + e.message);
      }
      driverInstance = null;
    }
  });
}

module.exports = {
  setupTestContext,
  getDriver: () => driverInstance
};
