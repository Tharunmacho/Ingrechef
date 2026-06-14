const { remote } = require('webdriverio');
const config = require('./config/appium.config');
const logger = require('./utilities/logger');

async function main() {
  logger.info('Starting layout dumper...');
  // Force Appium server configuration
  const options = {
    hostname: config.hostname,
    port: config.port,
    path: config.path,
    capabilities: config.capabilities,
    logLevel: 'error'
  };

  const driver = await remote(options);
  try {
    logger.info('App launched. Waiting 6 seconds for Splash Screen animation to finish...');
    await new Promise(resolve => setTimeout(resolve, 6000));
    
    logger.info('Retrieving active page source hierarchy...');
    const source = await driver.getPageSource();
    console.log('=== PAGE SOURCE START ===');
    console.log(source);
    console.log('=== PAGE SOURCE END ===');
  } catch (err) {
    logger.error('Failed: ' + err.message);
  } finally {
    await driver.deleteSession();
  }
}

main();
