const logger = require('./logger');

class GestureUtils {
  static async getCoordinates(driver, element) {
    const location = await element.getLocation();
    const size = await element.getSize();
    return {
      x: location.x + size.width / 2,
      y: location.y + size.height / 2
    };
  }

  static async tap(driver, element) {
    const coords = await this.getCoordinates(driver, element);
    logger.info(`Performing W3C Tap action at coordinates: (${coords.x}, ${coords.y})`);
    await driver.performActions([{
      type: 'pointer',
      id: 'finger1',
      parameters: { pointerType: 'touch' },
      actions: [
        { type: 'pointerMove', duration: 0, x: Math.round(coords.x), y: Math.round(coords.y) },
        { type: 'pointerDown', button: 0 },
        { type: 'pause', duration: 100 },
        { type: 'pointerUp', button: 0 }
      ]
    }]);
  }

  static async doubleTap(driver, element) {
    const coords = await this.getCoordinates(driver, element);
    logger.info(`Performing W3C Double Tap action at coordinates: (${coords.x}, ${coords.y})`);
    await driver.performActions([{
      type: 'pointer',
      id: 'finger1',
      parameters: { pointerType: 'touch' },
      actions: [
        { type: 'pointerMove', duration: 0, x: Math.round(coords.x), y: Math.round(coords.y) },
        { type: 'pointerDown', button: 0 },
        { type: 'pause', duration: 80 },
        { type: 'pointerUp', button: 0 },
        { type: 'pause', duration: 80 },
        { type: 'pointerDown', button: 0 },
        { type: 'pause', duration: 80 },
        { type: 'pointerUp', button: 0 }
      ]
    }]);
  }

  static async longPress(driver, element, durationMs = 1500) {
    const coords = await this.getCoordinates(driver, element);
    logger.info(`Performing W3C Long Press action (duration: ${durationMs}ms) at coordinates: (${coords.x}, ${coords.y})`);
    await driver.performActions([{
      type: 'pointer',
      id: 'finger1',
      parameters: { pointerType: 'touch' },
      actions: [
        { type: 'pointerMove', duration: 0, x: Math.round(coords.x), y: Math.round(coords.y) },
        { type: 'pointerDown', button: 0 },
        { type: 'pause', duration: durationMs },
        { type: 'pointerUp', button: 0 }
      ]
    }]);
  }

  static async swipe(driver, startX, startY, endX, endY, durationMs = 800) {
    logger.info(`Performing W3C Swipe action from (${startX}, ${startY}) to (${endX}, ${endY})`);
    await driver.performActions([{
      type: 'pointer',
      id: 'finger1',
      parameters: { pointerType: 'touch' },
      actions: [
        { type: 'pointerMove', duration: 0, x: Math.round(startX), y: Math.round(startY) },
        { type: 'pointerDown', button: 0 },
        { type: 'pause', duration: 100 },
        { type: 'pointerMove', duration: durationMs, x: Math.round(endX), y: Math.round(endY) },
        { type: 'pointerUp', button: 0 }
      ]
    }]);
    await driver.pause(500); // Wait for inertia to settle
  }

  static async swipeLeft(driver, ratio = 0.8) {
    const size = await driver.getWindowSize();
    const startX = size.width * ratio;
    const endX = size.width * (1 - ratio);
    const y = size.height / 2;
    await this.swipe(driver, startX, y, endX, y);
  }

  static async swipeRight(driver, ratio = 0.8) {
    const size = await driver.getWindowSize();
    const startX = size.width * (1 - ratio);
    const endX = size.width * ratio;
    const y = size.height / 2;
    await this.swipe(driver, startX, y, endX, y);
  }

  static async swipeUp(driver, ratio = 0.7) {
    const size = await driver.getWindowSize();
    const x = size.width / 2;
    const startY = size.height * 0.75;
    const endY = size.height * 0.35;
    await this.swipe(driver, x, startY, x, endY);
  }

  static async swipeDown(driver, ratio = 0.7) {
    const size = await driver.getWindowSize();
    const x = size.width / 2;
    const startY = size.height * 0.35;
    const endY = size.height * 0.75;
    await this.swipe(driver, x, startY, x, endY);
  }

  static async dragAndDrop(driver, sourceElement, targetElement) {
    const startCoords = await this.getCoordinates(driver, sourceElement);
    const endCoords = await this.getCoordinates(driver, targetElement);
    logger.info(`Performing W3C Drag and Drop from (${startCoords.x}, ${startCoords.y}) to (${endCoords.x}, ${endCoords.y})`);
    
    await driver.performActions([{
      type: 'pointer',
      id: 'finger1',
      parameters: { pointerType: 'touch' },
      actions: [
        { type: 'pointerMove', duration: 0, x: Math.round(startCoords.x), y: Math.round(startCoords.y) },
        { type: 'pointerDown', button: 0 },
        { type: 'pause', duration: 500 },
        { type: 'pointerMove', duration: 1000, x: Math.round(endCoords.x), y: Math.round(endCoords.y) },
        { type: 'pointerUp', button: 0 }
      ]
    }]);
  }

  static async scrollUntilVisible(driver, targetSelector, maxSwipes = 8, direction = 'down') {
    logger.info(`Scrolling ${direction} until visible: ${targetSelector}`);
    const size = await driver.getWindowSize();
    const x = size.width / 2;
    
    let startY, endY;
    if (direction === 'down') {
      startY = size.height * 0.7;
      endY = size.height * 0.3;
    } else {
      startY = size.height * 0.3;
      endY = size.height * 0.7;
    }

    for (let i = 0; i < maxSwipes; i++) {
      const el = await driver.$(targetSelector);
      if (await el.isExisting() && await el.isDisplayed()) {
        logger.info(`Element ${targetSelector} found visible after ${i} scrolls.`);
        return el;
      }
      logger.info(`Element not visible. Scroll iteration ${i + 1}/${maxSwipes}`);
      await this.swipe(driver, x, startY, x, endY);
    }
    throw new Error(`Element ${targetSelector} not visible after ${maxSwipes} scrolls`);
  }

  static async pinch(driver, element) {
    const coords = await this.getCoordinates(driver, element);
    const size = await element.getSize();
    const offset = Math.round(size.width * 0.25);
    logger.info(`Performing W3C Pinch action centered on (${coords.x}, ${coords.y})`);

    await driver.performActions([
      {
        type: 'pointer',
        id: 'finger1',
        parameters: { pointerType: 'touch' },
        actions: [
          { type: 'pointerMove', duration: 0, x: coords.x - offset, y: coords.y },
          { type: 'pointerDown', button: 0 },
          { type: 'pause', duration: 100 },
          { type: 'pointerMove', duration: 600, x: coords.x - 10, y: coords.y },
          { type: 'pointerUp', button: 0 }
        ]
      },
      {
        type: 'pointer',
        id: 'finger2',
        parameters: { pointerType: 'touch' },
        actions: [
          { type: 'pointerMove', duration: 0, x: coords.x + offset, y: coords.y },
          { type: 'pointerDown', button: 0 },
          { type: 'pause', duration: 100 },
          { type: 'pointerMove', duration: 600, x: coords.x + 10, y: coords.y },
          { type: 'pointerUp', button: 0 }
        ]
      }
    ]);
  }

  static async zoom(driver, element) {
    const coords = await this.getCoordinates(driver, element);
    const size = await element.getSize();
    const offset = Math.round(size.width * 0.25);
    logger.info(`Performing W3C Zoom action centered on (${coords.x}, ${coords.y})`);

    await driver.performActions([
      {
        type: 'pointer',
        id: 'finger1',
        parameters: { pointerType: 'touch' },
        actions: [
          { type: 'pointerMove', duration: 0, x: coords.x - 10, y: coords.y },
          { type: 'pointerDown', button: 0 },
          { type: 'pause', duration: 100 },
          { type: 'pointerMove', duration: 600, x: coords.x - offset, y: coords.y },
          { type: 'pointerUp', button: 0 }
        ]
      },
      {
        type: 'pointer',
        id: 'finger2',
        parameters: { pointerType: 'touch' },
        actions: [
          { type: 'pointerMove', duration: 0, x: coords.x + 10, y: coords.y },
          { type: 'pointerDown', button: 0 },
          { type: 'pause', duration: 100 },
          { type: 'pointerMove', duration: 600, x: coords.x + offset, y: coords.y },
          { type: 'pointerUp', button: 0 }
        ]
      }
    ]);
  }
}

module.exports = GestureUtils;
