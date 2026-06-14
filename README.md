# Ingrechef - Enterprise Appium E2E Automation Framework

An enterprise-grade, robust, and scalable End-to-End (E2E) mobile test automation framework designed for the **Ingrechef** Android application. It utilizes **Appium 2.x**, **Node.js**, **Mocha**, **Chai**, and **WebDriverIO** (as the Appium client) inside a modular **Page Object Model (POM)** architecture.

---

## 🌟 Key Features

* **Automation Platform**: Appium 2.x with UiAutomator2 driver.
* **Architecture**: Object-oriented Page Object Model (POM).
* **Launch Strategies**: Supports both dynamic APK installation and executing against already installed packages.
* **Auto-Discovery**: Dynamically queries active Android devices and Android OS versions via ADB.
* **Gestures Layer**: Built-in W3C pointer actions for Taps, Long-Presses, Swipes, Scrolls, and multi-finger Pinches/Zooms.
* **Fail-Safe Diagnostics**: Automatically captures high-resolution screenshots, device Logcat logs, and current activity names upon failure.
* **Premium Excel Reporting**: Generates a forest green branded `excel/Mobile_E2E_Report.xlsx` report across 4 tabs:
  1. *Summary*: Metric indicators, pass rates, and durations.
  2. *Test Cases*: Grid of all scenario details and individual speeds.
  3. *Failed Tests*: Stack trace reasons, screenshots, and logs path mappings.
  4. *Execution Logs*: Action-by-action logs recorded chronologically.
* **HTML Reporting**: Generates standard Mochawesome reports.
* **CI/CD Integrated**: Configured with GitHub Actions workflow for automatic headless test runs.

---

## 📂 Project Structure

```text
project-root/
├── .github/workflows/
│   └── appium-e2e.yml           # CI/CD GitHub Actions pipeline configuration
└── automation/                  # E2E Mobile Test Automation Framework
    ├── config/
    │   └── appium.config.js     # Port, host, package info, capability configurations
    ├── drivers/
    │   └── driverFactory.js     # Driver initialization & dynamic ADB device detection
    ├── pages/                   # Page Object Models (POM)
    │   ├── basePage.js          # Base Page Object (common waits, wrappers)
    │   ├── loginPage.js         # Page Object for Sign In & Sign Up
    │   ├── dashboardPage.js     # Page Object for Dashboard actions
    │   ├── ingredientsPage.js   # Page Object for Pantry/Ingredients tracker
    │   ├── mealGeneratorPage.js # Page Object for AI Meal Planner
    │   ├── recipeDetailPage.js # Page Object for Recipe details page
    │   └── profilePage.js       # Page Object for User Profile & Logout
    ├── tests/                   # Mocha Test Cases
    │   ├── baseTest.js          # Base test setup (Mocha hooks, metrics, screenshot-on-failure)
    │   ├── auth.test.js         # Test suite for authentication & logout
    │   ├── form.test.js         # Test suite for form validation rules
    │   ├── gestures.test.js     # Test suite for gesture-specific validations
    │   └── e2e.test.js          # End-to-end user workflow test
    ├── utilities/               # Core Helpers
    │   ├── logger.js            # Winston-based logger (file and console output)
    │   ├── excelReporter.js     # Custom ExcelJS reporter generating 4 sheets
    │   ├── appiumUtils.js       # Wait helpers, screenshots, logcat logs, activities
    │   └── gestureUtils.js      # Reusable W3C Actions API gestures (swipe, scroll, drag, pinch)
    ├── .env.example             # Configuration environment template
    ├── package.json             # Node.js dependencies, scripts, and metadata
    └── verify_imports.js        # Internal imports check utility
```

---

## 🛠️ Prerequisites & Setup

### 1. System Requirements
* **Node.js** (v18+)
* **Java Development Kit (JDK)** (v11 or v17)
* **Android SDK** (Android Studio with Platform Tools configured in environment PATH variables)
* **Appium Server** & **Drivers**

### 2. Installations

Install the Appium Server globally:
```bash
npm install -g appium
```

Install the UiAutomator2 driver:
```bash
appium driver install uiautomator2
```

Navigate into the automation directory and install dependencies:
```bash
cd automation
npm install
```

### 3. Environment Parameters Configuration
Create `.env` from `.env.example` inside the `automation` directory:
```bash
cd automation
copy .env.example .env
```
Modify variables in `.env` based on your environment:
* Set `APP_LAUNCH_TYPE` to `APK` if you want Appium to build/install the app from `APK_PATH`.
* Set `APP_LAUNCH_TYPE` to `INSTALLED` if you already have the app on your emulator and want to launch by Package/Activity names.

---

## 🚀 Execution Instructions

First, launch the Appium server on your machine:
```bash
appium
```

Ensure an Android emulator is running or a physical device is connected with USB Debugging enabled:
```bash
adb devices
```

### Run Commands
Always navigate into the `automation/` folder before running test scripts:
```bash
cd automation
```

* **Verify local imports setup**:
  ```bash
  node verify_imports.js
  ```
* **Run all test suites**:
  ```bash
  npm test
  ```
* **Run End-to-End user workflows**:
  ```bash
  npm run test:e2e
  ```
* **Run Authentication suite**:
  ```bash
  npm run test:auth
  ```
* **Run Form validation suite**:
  ```bash
  npm run test:form
  ```
* **Run Gestures suite**:
  ```bash
  npm run test:gestures
  ```

---

## 📊 Reporting and Logging

### 1. Excel Report (`excel/Mobile_E2E_Report.xlsx`)
At the end of test runs, a styled spreadsheet is generated. It includes color-coded status banners, font sizing, and borders aligning with the forest green aesthetic.

### 2. Mochawesome HTML Report
HTML reports can be found in `mochawesome-report/mochawesome.html`. To compile a single standalone dashboard, run:
```bash
npx marge mochawesome-report/mochawesome.json --reportDir reports/html --reportFilename index.html
```

### 3. Failure Screenshots and Logs
Whenever a failure occurs, the following items are dumped inside the `reports/failures/` folder:
* **Screenshot**: Saved as `<scenario_name>_<timestamp>.png`
* **Logcat Log**: Retracted last 150 logcat logs, saved as `<scenario_name>_logcat_<timestamp>.txt`

---

## 🤖 AI Smart Testing Agent Guide

This framework is built to support autonomous AI test agents. The page objects expose high-level semantic selectors and actions:
1. **Locators**: Most selectors check for text patterns (`//android.widget.TextView[@text="..."]`) or accessibility labels (`//android.widget.ImageView[contains(@content-desc, "...")]`).
2. **Dynamic Discoveries**: AI agents can inspect components by calling the `isElementVisible(xpath)` wrapper or query toast notifications using `getToastOrSnackbar()`.
3. **Execution Pipeline**: An agent can extend validations by adding tests inside the `tests/` folder. All dependencies and logs will automatically route to the Excel Reporter without requiring manual config alterations.
