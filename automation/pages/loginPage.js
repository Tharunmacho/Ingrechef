const BasePage = require('./basePage');
const logger = require('../utilities/logger');

/**
 * LoginPage - Page Object for Login/Registration screen.
 *
 * Key findings from UI dump (Flutter on Android):
 * - ALL Flutter Text widgets render as android.view.View with @content-desc (NOT @text)
 * - Tab buttons: android.view.View @content-desc="Sign In" / "Sign Up", clickable="true"
 * - Input fields: android.widget.EditText (only 2 on Sign In, 5 on Sign Up)
 * - The submit button: android.view.View @content-desc="Sign In" or "Create Account", clickable="true"
 *   (same content-desc as the tab for Sign In mode — we need to distinguish by position/index)
 */
class LoginPage extends BasePage {
  constructor(driver) {
    super(driver);
  }

  // ── Tab selectors (android.view.View with @content-desc, clickable=true) ───
  // The tab "Sign In" has bounds in top half of screen (around y=612-752)
  // Use content-desc since @text is EMPTY for all Flutter views
  get signInTabBtn()  { return '//*[@content-desc="Sign In" and @clickable="true"]'; }
  get signUpTabBtn()  { return '//*[@content-desc="Sign Up" and @clickable="true"]'; }

  // ── Input fields (use index-based since no resource-id) ──────────────────
  // Sign In form:  EditText[1]=email, EditText[2]=password
  // Sign Up form:  EditText[1]=name, EditText[2]=email, EditText[3]=phone, EditText[4]=pwd, EditText[5]=confirm
  get emailEditText()   { return '(//android.widget.EditText[@password="false"])[1]'; }
  get passwordEditText(){ return '(//android.widget.EditText[@password="true"])[1]'; }
  get confirmPwdEditText(){ return '(//android.widget.EditText[@password="true"])[2]'; }

  // Sign Up only - name and phone (non-password, non-email fields)
  // After name=1st non-pwd field, email=2nd non-pwd field, phone=3rd non-pwd field
  get nameEditText()  { return '(//android.widget.EditText[@password="false"])[1]'; }
  get signUpEmailEditText() { return '(//android.widget.EditText[@password="false"])[2]'; }
  get phoneEditText() { return '(//android.widget.EditText[@password="false"])[3]'; }

  // ── Submit button ─────────────────────────────────────────────────────────
  // The submit button is a view with content-desc "Sign In" or "Create Account"
  // It's the LAST clickable view with that content-desc (the tab is first, button is second)
  // OR identify by bounds (button is in lower half of screen, tab is in top half)

  // ── Methods ───────────────────────────────────────────────────────────────
  async switchToSignIn() {
    logger.info('Switching to Sign In tab...');
    try {
      const els = await this.driver.$$('//*[@content-desc="Sign In" and @clickable="true"]');
      if (els.length > 0) {
        await els[0].click();
        logger.info(`Clicked Sign In tab (found ${els.length} elements)`);
      } else {
        logger.warn('Sign In tab not found — may already be on Sign In tab, continuing...');
      }
    } catch (e) {
      logger.warn('switchToSignIn click failed (continuing): ' + e.message);
    }
    await this.driver.pause(600);
  }

  async switchToSignUp() {
    logger.info('Switching to Sign Up tab...');
    try {
      const els = await this.driver.$$('//*[@content-desc="Sign Up" and @clickable="true"]');
      if (els.length > 0) {
        await els[0].click();
        logger.info(`Clicked Sign Up tab (found ${els.length} elements)`);
      } else {
        logger.warn('Sign Up tab not found — may already be on Sign Up tab, continuing...');
      }
    } catch (e) {
      logger.warn('switchToSignUp click failed (continuing): ' + e.message);
    }
    await this.driver.pause(800); // Wait for AnimatedCrossFade transition
  }

  async fillSignInForm(email, password) {
    logger.info(`Filling Sign In Form: email="${email}"`);
    // Dismiss keyboard first in case it's covering elements
    await this.hideKeyboard();
    await this.driver.pause(300);
    // Sign In form: EditText[1]=email (password=false), EditText[2]=password (password=true)
    // Use waitForExist (not waitForDisplayed) — EditText exists even under keyboard
    if (email !== null && email !== undefined) {
      const emailEl = await this.driver.$('(//android.widget.EditText)[1]');
      await emailEl.waitForExist({ timeout: 12000 });
      await emailEl.click();
      await emailEl.clearValue();
      let val = await emailEl.getText();
      if (val && val.length > 0) {
        logger.info(`Email field still has text: "${val}". Sending backspaces...`);
        for (let i = 0; i < val.length + 5; i++) {
          await this.driver.pressKeyCode(67); // Android del keycode
        }
      }
      if (email !== '') await emailEl.setValue(email);
    }
    if (password !== null && password !== undefined) {
      const pwdEl = await this.driver.$('(//android.widget.EditText)[2]');
      await pwdEl.waitForExist({ timeout: 12000 });
      await pwdEl.click();
      await pwdEl.clearValue();
      let val = await pwdEl.getText();
      if (val && val.length > 0) {
        logger.info(`Password field still has text (masked). Sending backspaces...`);
        for (let i = 0; i < 24; i++) {
          await this.driver.pressKeyCode(67);
        }
      }
      if (password !== '') await pwdEl.setValue(password);
    }
    await this.hideKeyboard();
  }

  async fillSignUpForm(name, email, phone, password, confirmPassword) {
    logger.info(`Filling Sign Up Form: name="${name}", email="${email}"`);
    // Dismiss keyboard first
    await this.hideKeyboard();
    await this.driver.pause(300);
    // Sign Up form has 5 EditText fields in order: name, email, phone, password, confirmPassword
    const allEdits = await this.driver.$$('//android.widget.EditText');
    logger.info(`Found ${allEdits.length} EditText elements on Sign Up form`);

    const fields = [name, email, phone, password, confirmPassword];
    for (let i = 0; i < Math.min(fields.length, allEdits.length); i++) {
      const val = fields[i];
      if (val !== null && val !== undefined) {
        try {
          // Use waitForExist — fields exist even when keyboard covers them
          await allEdits[i].waitForExist({ timeout: 8000 });
          await allEdits[i].click();
          await allEdits[i].clearValue();
          let currentVal = await allEdits[i].getText();
          if (currentVal && currentVal.length > 0) {
            for (let j = 0; j < Math.max(currentVal.length + 5, 24); j++) {
              await this.driver.pressKeyCode(67);
            }
          }
          if (val !== '') await allEdits[i].setValue(val);
          // Dismiss keyboard between fields to prevent coverage issues
          await this.hideKeyboard();
        } catch (e) {
          logger.warn(`Could not fill field[${i}] with "${val}": ${e.message}`);
        }
      }
    }
    await this.hideKeyboard();
  }

  async clickSubmit() {
    logger.info('Clicking Submit / action button on Login page...');
    // Dismiss keyboard first — submit button may be scrolled below keyboard
    await this.hideKeyboard();
    await this.driver.pause(600); // Let scroll view settle after keyboard dismissal

    let clicked = false;

    // Try "Create Account" first (Sign Up mode)
    try {
      const createEl = await this.driver.$('//*[@content-desc="Create Account" and @clickable="true"]');
      if (await createEl.isExisting()) {
        await createEl.click();
        logger.info('Clicked "Create Account" submit button');
        clicked = true;
      }
    } catch (_) {}

    if (!clicked) {
      // Try all "Sign In" clickable elements — submit button and tab both have this content-desc
      // The submit button is BELOW the form (larger y-coordinate than the tab)
      try {
        const signInEls = await this.driver.$$('//*[@content-desc="Sign In" and @clickable="true"]');
        if (signInEls.length >= 2) {
          // Last element by DOM order = the submit button (rendered after the tab)
          await signInEls[signInEls.length - 1].click();
          logger.info('Clicked "Sign In" submit button (last element)');
          clicked = true;
        } else if (signInEls.length === 1) {
          await signInEls[0].click();
          logger.info('Clicked "Sign In" submit button (only element)');
          clicked = true;
        }
      } catch (e) {
        logger.warn('Could not find Sign In button by content-desc: ' + e.message);
      }
    }

    if (!clicked) {
      // Scroll down to reveal submit button then tap it
      logger.warn('Submit button not found — scrolling down and retrying...');
      const size = await this.driver.getWindowSize();
      // Scroll down a bit
      await this.driver.action('pointer')
        .move({ x: size.width / 2, y: size.height * 0.6 })
        .down()
        .move({ x: size.width / 2, y: size.height * 0.3 })
        .up()
        .perform();
      await this.driver.pause(600);

      try {
        const els = await this.driver.$$('//*[@content-desc="Sign In" and @clickable="true"]');
        if (els.length > 0) {
          await els[els.length - 1].click();
          clicked = true;
          logger.info('Clicked submit after scroll');
        }
        const createEl = await this.driver.$('//*[@content-desc="Create Account" and @clickable="true"]');
        if (!clicked && await createEl.isExisting()) {
          await createEl.click();
          clicked = true;
        }
      } catch (_) {}
    }

    if (!clicked) {
      logger.warn('All submit strategies failed — using coordinate tap');
      const size = await this.driver.getWindowSize();
      await this.driver.action('pointer')
        .move({ x: Math.round(size.width / 2), y: Math.round(size.height * 0.72) })
        .down().up().perform();
    }

    await this.driver.pause(2000); // Wait for API response + SnackBar
  }

  async getValidationMessage() {
    logger.info('Retrieving SnackBar / Toast validation message...');
    return await this.getToastOrSnackbar();
  }

  async login(email, password) {
    await this.switchToSignIn();
    await this.fillSignInForm(email, password);
    await this.clickSubmit();
  }

  // Check that we are on the login screen by looking for the tab buttons
  async isOnLoginScreen() {
    // Dismiss keyboard first so tabs are not hidden behind it
    await this.hideKeyboard();
    await this.driver.pause(500);
    return await this.isElementVisible(this.signInTabBtn, 5000);
  }
}

module.exports = LoginPage;
