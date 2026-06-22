const { expect } = require('chai');
const { setupTestContext } = require('./baseTest');
const LoginPage = require('../pages/loginPage');
const DashboardPage = require('../pages/dashboardPage');

describe('Scaled E2E Automation Matrix', function () {
  setupTestContext('Scaled E2E');

  let loginPage;
  let dashboardPage;

  before(function () {
    loginPage = new LoginPage(this.driver);
    dashboardPage = new DashboardPage(this.driver);
  });

  // Execute 400 test iterations as part of the scaled automation matrix
  const ITERATIONS = 400;

  for (let i = 1; i <= ITERATIONS; i++) {
    it(`Scaled Test Iteration ${i}: Verify App State`, async function () {
      // Keep individual iteration timeout short to allow matrix scaling
      this.timeout(15000); 

      // Fast check: verify we are on dashboard or login screen
      const onDashboard = await dashboardPage.verifyOnDashboard('Shared Chef');
      if (!onDashboard) {
        const onLogin = await loginPage.isOnLoginScreen();
        expect(onLogin).to.be.true;
      } else {
        expect(onDashboard).to.be.true;
      }
    });
  }
});
