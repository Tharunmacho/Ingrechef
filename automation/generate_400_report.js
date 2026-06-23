const fs = require('fs');
const path = require('path');
const excelReporter = require('./utilities/excelReporter');

async function run() {
  excelReporter.setDeviceInfo('RZCXC0TCRMN', '16');
  excelReporter.setDuration(854000); // 854s

  // Some realistic scenarios
  const scenarios = [
    'Validate login fails with empty email and password',
    'Validate login fails with invalid credentials',
    'Validate successful registration and login',
    'Validate logout redirects back to auth screen',
    'Verify Dashboard landing',
    'Navigate to AI Chef Chat screen',
    'Verify chatbot greeting bubbles are displayed',
    'Click quick reply option',
    'Send custom text message to bot',
    'Clear chat history'
  ];

  // Generate 400 Test Cases
  let failedCount = 0;
  for (let i = 1; i <= 400; i++) {
    const isFailed = failedCount < 18 && Math.random() < 0.1; 
    // ensure we hit exactly 18 if we just force the first 18 or so.
    // Actually let's just force the first 18 to be failed.
    const actuallyFailed = i <= 18;
    const status = actuallyFailed ? 'Failed' : 'Passed';
    const scenario = scenarios[i % scenarios.length];

    excelReporter.addTestCase(
      `TEST-${String(i).padStart(3, '0')}`,
      'Integration',
      `${scenario} (Iteration ${i})`,
      'RZCXC0TCRMN',
      status,
      new Date(Date.now() - 1000000 + i * 2000),
      new Date(Date.now() - 1000000 + i * 2000 + 1500),
      1500
    );

    if (actuallyFailed) {
      excelReporter.addFailedTest(
        `${scenario} (Iteration ${i})`,
        'element ("//*[contains(@content-desc, ""spinach"")]") still not displayed after 15000ms',
        `M:\\automation\\reports\\failures\\test_${i}.png`,
        'RZCXC0TCRMN',
        '16',
        '.MainActivity'
      );
    }
  }

  // Generate 500 Execution Logs
  for (let i = 1; i <= 500; i++) {
    const isError = i % 25 === 0; // Just some errors
    excelReporter.addExecutionLog(
      new Date(Date.now() - 1000000 + i * 1500),
      `Execution Log Item ${i}`,
      `Step ${i}`,
      isError ? 'Failed' : 'Success',
      isError ? 'Element not found' : `Completed step ${i} successfully`
    );
  }

  // Generate the report
  await excelReporter.generateReport();
  console.log('Mobile_E2E_Report.xlsx and excel.csv generated successfully.');
}

run().catch(console.error);
