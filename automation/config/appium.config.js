const path = require('path');
require('dotenv').config();

const config = {
  hostname: process.env.APPIUM_HOST || '127.0.0.1',
  port: parseInt(process.env.APPIUM_PORT, 10) || 4723,
  path: process.env.APPIUM_PATH || '/',
  
  environment: process.env.ENVIRONMENT || 'staging',
  launchType: process.env.APP_LAUNCH_TYPE || 'APK', // 'APK' or 'INSTALLED'
  
  capabilities: {
    platformName: 'Android',
    'appium:automationName': 'UiAutomator2',
    'appium:deviceName': process.env.DEVICE_NAME || 'Android Emulator',
    'appium:platformVersion': process.env.PLATFORM_VERSION || '14.0',
    'appium:noReset': false,
    'appium:fullReset': false,
    'appium:newCommandTimeout': 300,
    'appium:ensureWebviewsHavePages': true,
    'appium:nativeWebScreenshot': true,
    'appium:connectHardwareKeyboard': true
  }
};

// Set dynamic capabilities based on the launch strategy
if (config.launchType.toUpperCase() === 'APK') {
  const apkRelativePath = process.env.APK_PATH || './build/app/outputs/flutter-apk/app-debug.apk';
  config.capabilities['appium:app'] = path.resolve(process.cwd(), apkRelativePath);
} else {
  config.capabilities['appium:appPackage'] = process.env.APP_PACKAGE || 'com.example.ingrechef';
  config.capabilities['appium:appActivity'] = process.env.APP_ACTIVITY || 'com.example.ingrechef.MainActivity';
}

module.exports = config;
