const { expect } = require('chai');
const { setupTestContext } = require('./baseTest');
const LoginPage = require('../pages/loginPage');

describe('Form Validation Testing', function () {
  setupTestContext('Form Validation');
  
  let loginPage;

  before(function () {
    loginPage = new LoginPage(this.driver);
  });

  it('Validate registration fails when required fields are empty', async function () {
    await loginPage.switchToSignUp();
    // Provide name only, leave email/phone/password empty
    await loginPage.fillSignUpForm('Chef Tester', '', '', '', '');
    
    // Start snackbar detection BEFORE clickSubmit's 2s pause ends
    // clickSubmit has a 2s built-in pause; getValidationMessage polls for 7s total
    await loginPage.clickSubmit();
    // Poll immediately — don't add extra pause
    const msg = await loginPage.getValidationMessage();

    if (msg !== null && msg !== undefined && msg.trim().length > 0) {
      // Snackbar captured — accept any validation message content
      expect(msg.length).to.be.greaterThan(0);
    } else {
      // No snackbar captured — verify we're still on signup screen (not navigated to dashboard)
      await this.driver.pause(1000); // extra settle time
      await loginPage.hideKeyboard();
      await this.driver.pause(800);
      const isStillOnSignUp = await loginPage.isElementVisible(loginPage.signUpTabBtn, 8000);
      expect(isStillOnSignUp, 'App should remain on signup screen after empty field submit').to.be.true;
    }
  });

  it('Validate password confirmation mismatch fails', async function () {
    await loginPage.switchToSignUp();
    await loginPage.fillSignUpForm(
      'Chef Tester',
      'chef_tester_error@example.com',
      '9876543210',
      'Password123!',
      'DifferentPassword321!'
    );
    
    await loginPage.clickSubmit();
    // Poll immediately for snackbar
    const msg = await loginPage.getValidationMessage();

    if (msg !== null && msg !== undefined && msg.trim().length > 0) {
      // Snackbar captured
      expect(msg.length).to.be.greaterThan(0);
    } else {
      // No snackbar — verify still on signup screen
      await this.driver.pause(1000);
      await loginPage.hideKeyboard();
      await this.driver.pause(800);
      const isStillOnSignUp = await loginPage.isElementVisible(loginPage.signUpTabBtn, 8000);
      expect(isStillOnSignUp, 'App should remain on signup screen after password mismatch').to.be.true;
    }
  });
});
