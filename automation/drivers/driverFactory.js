const { remote } = require('webdriverio');
const { execSync } = require('child_process');
const config = require('../config/appium.config');
const logger = require('../utilities/logger');

class DriverFactory {
  static detectDevice() {
    try {
      logger.info('Attempting to dynamically detect connected Android devices/emulators via ADB...');
      const stdout = execSync('adb devices').toString();
      const lines = stdout.split('\n');
      const devices = [];

      for (let i = 1; i < lines.length; i++) {
        const line = lines[i].trim();
        if (line && !line.startsWith('*') && !line.startsWith('List of devices') && line.includes('device')) {
          const parts = line.split(/\s+/);
          if (parts.length >= 2 && parts[1] === 'device') {
            devices.push(parts[0]);
          }
        }
      }

      if (devices.length > 0) {
        logger.info(`Detected connected Android devices: ${JSON.stringify(devices)}`);
        logger.info(`Selected active device: ${devices[0]} for test execution.`);
        return devices[0];
      } else {
        logger.warn('No active Android devices detected via ADB. Falling back to default capability configuration.');
        return null;
      }
    } catch (error) {
      logger.warn(`ADB device detection failed (is Android SDK / adb in your PATH?): ${error.message}. Falling back to default configuration.`);
      return null;
    }
  }

  static async getAndroidVersion(udid) {
    if (!udid) return '14.0';
    try {
      const version = execSync(`adb -s ${udid} shell getprop ro.build.version.release`).toString().trim();
      logger.info(`Detected Android Version for device ${udid}: ${version}`);
      return version;
    } catch (e) {
      logger.warn(`Failed to detect Android version for device ${udid}: ${e.message}. Defaulting to 14.0.`);
      return '14.0';
    }
  }

  static async createDriver() {
    const caps = { ...config.capabilities };
    
    // Dynamic device detection
    const connectedUdid = this.detectDevice();
    if (connectedUdid) {
      caps['appium:udid'] = connectedUdid;
      caps['appium:deviceName'] = connectedUdid;
      caps['appium:platformVersion'] = await this.getAndroidVersion(connectedUdid);
    }

    logger.info('Initializing Appium Driver Session...', {
      hostname: config.hostname,
      port: config.port,
      path: config.path,
      capabilities: {
        platformName: caps.platformName,
        deviceName: caps['appium:deviceName'],
        platformVersion: caps['appium:platformVersion'],
        app: caps['appium:app'] ? 'APK_PATH_CONFIGURED' : undefined,
        appPackage: caps['appium:appPackage'],
        appActivity: caps['appium:appActivity']
      }
    });

    const options = {
      hostname: config.hostname,
      port: config.port,
      path: config.path,
      capabilities: caps,
      logLevel: 'error'
    };

    try {
      const driver = await remote(options);
      logger.info('Appium Driver Session successfully established! Session ID: ' + driver.sessionId);
      return driver;
    } catch (err) {
      logger.error('Failed to create Appium Driver Session: ' + err.message, err);
      throw err;
    }
  }
}

module.exports = DriverFactory;
