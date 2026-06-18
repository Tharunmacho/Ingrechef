const ExcelJS = require('exceljs');
const path = require('path');
const fs = require('fs');

class ExcelReporter {
  constructor() {
    this.reportDir = path.join(__dirname, '..', 'excel');
    this.reportPath = path.join(this.reportDir, 'Mobile_E2E_Report.xlsx');
    this.workbook = new ExcelJS.Workbook();
    
    this.summaryData = {
      executionDate: new Date().toISOString().split('T')[0],
      deviceName: 'Unknown',
      androidVersion: 'Unknown',
      total: 0,
      passed: 0,
      failed: 0,
      skipped: 0,
      duration: 0
    };

    this.testCases = [];
    this.failedTests = [];
    this.executionLogs = [];
  }

  setDeviceInfo(deviceName, androidVersion) {
    this.summaryData.deviceName = deviceName || 'Unknown';
    this.summaryData.androidVersion = androidVersion || 'Unknown';
  }

  addTestCase(testId, module, scenario, device, status, startTime, endTime, duration) {
    this.testCases.push({ testId, module, scenario, device, status, startTime, endTime, duration });
    this.summaryData.total++;
    if (status === 'Passed') this.summaryData.passed++;
    else if (status === 'Failed') this.summaryData.failed++;
    else if (status === 'Skipped') this.summaryData.skipped++;
  }

  addFailedTest(testName, failureReason, screenshotPath, device, androidVersion, activityName) {
    this.failedTests.push({ testName, failureReason, screenshotPath, device, androidVersion, activityName });
  }

  addExecutionLog(timestamp, testName, step, result, remarks) {
    this.executionLogs.push({ timestamp, testName, step, result, remarks });
  }

  setDuration(durationMs) {
    this.summaryData.duration = (durationMs / 1000).toFixed(2) + 's';
  }

  async generateReport() {
    if (!fs.existsSync(this.reportDir)) {
      fs.mkdirSync(this.reportDir, { recursive: true });
    }

    // Clear old sheets if generating again
    while (this.workbook.worksheets.length > 0) {
      this.workbook.removeWorksheet(this.workbook.worksheets[0].id);
    }

    // 1. Summary Sheet
    const summarySheet = this.workbook.addWorksheet('Summary');
    summarySheet.columns = [
      { header: 'Execution Date', key: 'executionDate', width: 15 },
      { header: 'Device Name', key: 'deviceName', width: 25 },
      { header: 'Android Version', key: 'androidVersion', width: 15 },
      { header: 'Total Tests', key: 'total', width: 12 },
      { header: 'Passed', key: 'passed', width: 10 },
      { header: 'Failed', key: 'failed', width: 10 },
      { header: 'Skipped', key: 'skipped', width: 10 },
      { header: 'Pass Percentage', key: 'passPercentage', width: 18 },
      { header: 'Execution Duration', key: 'duration', width: 20 }
    ];

    const passPct = this.summaryData.total > 0 
      ? ((this.summaryData.passed / this.summaryData.total) * 100).toFixed(2) + '%' 
      : '0.00%';

    summarySheet.addRow({
      executionDate: this.summaryData.executionDate,
      deviceName: this.summaryData.deviceName,
      androidVersion: this.summaryData.androidVersion,
      total: this.summaryData.total,
      passed: this.summaryData.passed,
      failed: this.summaryData.failed,
      skipped: this.summaryData.skipped,
      passPercentage: passPct,
      duration: this.summaryData.duration
    });

    // 2. Test Cases Sheet
    const tcSheet = this.workbook.addWorksheet('Test Cases');
    tcSheet.columns = [
      { header: 'Test ID', key: 'testId', width: 12 },
      { header: 'Module', key: 'module', width: 15 },
      { header: 'Scenario', key: 'scenario', width: 35 },
      { header: 'Device', key: 'device', width: 20 },
      { header: 'Status', key: 'status', width: 12 },
      { header: 'Start Time', key: 'startTime', width: 25 },
      { header: 'End Time', key: 'endTime', width: 25 },
      { header: 'Duration', key: 'duration', width: 15 }
    ];

    this.testCases.forEach(tc => {
      tcSheet.addRow({
        testId: tc.testId,
        module: tc.module,
        scenario: tc.scenario,
        device: tc.device,
        status: tc.status,
        startTime: tc.startTime ? tc.startTime.toISOString() : 'N/A',
        endTime: tc.endTime ? tc.endTime.toISOString() : 'N/A',
        duration: (tc.duration / 1000).toFixed(2) + 's'
      });
    });

    // 3. Failed Tests Sheet
    const failedSheet = this.workbook.addWorksheet('Failed Tests');
    failedSheet.columns = [
      { header: 'Test Name', key: 'testName', width: 30 },
      { header: 'Failure Reason', key: 'failureReason', width: 50 },
      { header: 'Screenshot Path', key: 'screenshotPath', width: 40 },
      { header: 'Device', key: 'device', width: 20 },
      { header: 'Android Version', key: 'androidVersion', width: 15 },
      { header: 'Activity Name', key: 'activityName', width: 30 }
    ];

    this.failedTests.forEach(ft => {
      failedSheet.addRow({
        testName: ft.testName,
        failureReason: ft.failureReason,
        screenshotPath: ft.screenshotPath,
        device: ft.device,
        androidVersion: ft.androidVersion,
        activityName: ft.activityName
      });
    });

    // 4. Execution Logs Sheet
    const logSheet = this.workbook.addWorksheet('Execution Logs');
    logSheet.columns = [
      { header: 'Timestamp', key: 'timestamp', width: 25 },
      { header: 'Test Name', key: 'testName', width: 30 },
      { header: 'Step', key: 'step', width: 30 },
      { header: 'Result', key: 'result', width: 15 },
      { header: 'Remarks', key: 'remarks', width: 45 }
    ];

    this.executionLogs.forEach(el => {
      logSheet.addRow({
        timestamp: el.timestamp ? el.timestamp.toISOString() : 'N/A',
        testName: el.testName,
        step: el.step,
        result: el.result,
        remarks: el.remarks
      });
    });

    // Premium styling
    this.workbook.worksheets.forEach(sheet => {
      // Style headers
      const headerRow = sheet.getRow(1);
      headerRow.font = { name: 'Calibri', bold: true, color: { argb: 'FFFFFFFF' }, size: 11 };
      headerRow.fill = {
        type: 'pattern',
        pattern: 'solid',
        fgColor: { argb: 'FF2D4A2D' } // Matches Ingrechef theme color (forest green)
      };
      headerRow.alignment = { vertical: 'middle', horizontal: 'left' };
      
      // Auto-fit rows and add thin borders
      sheet.eachRow((row, rowNumber) => {
        row.height = rowNumber === 1 ? 28 : 22;
        row.eachCell(cell => {
          cell.border = {
            top: { style: 'thin', color: { argb: 'FFE0E0E0' } },
            left: { style: 'thin', color: { argb: 'FFE0E0E0' } },
            bottom: { style: 'thin', color: { argb: 'FFE0E0E0' } },
            right: { style: 'thin', color: { argb: 'FFE0E0E0' } }
          };
          if (rowNumber > 1) {
            cell.font = { name: 'Calibri', size: 10 };
            
            // Color code Status columns
            if (cell.value === 'Passed') {
              cell.font = { name: 'Calibri', size: 10, bold: true, color: { argb: 'FF2E7D32' } };
            } else if (cell.value === 'Failed') {
              cell.font = { name: 'Calibri', size: 10, bold: true, color: { argb: 'FFC62828' } };
            } else if (cell.value === 'Skipped') {
              cell.font = { name: 'Calibri', size: 10, bold: true, color: { argb: 'FFF9A825' } };
            }
          }
        });
      });
    });

    try {
      await this.workbook.xlsx.writeFile(this.reportPath);
    } catch (e) {
      console.error(`[ExcelReporter] WARNING: Failed to write Excel report to ${this.reportPath}. It might be open in Excel. Error: ${e.message}`);
    }

    // Also write excel.csv containing the Test Cases tab in CSV format
    try {
      const csvPath = path.join(this.reportDir, 'excel.csv');
      const header = '"Test ID","Module","Scenario","Device","Status","Start Time","End Time","Duration"\n';
      const rows = this.testCases.map(tc => {
        const testId = tc.testId || '';
        const moduleVal = tc.module || '';
        const scenario = (tc.scenario || '').replace(/"/g, '""');
        const device = tc.device || '';
        const status = tc.status || '';
        const startTime = tc.startTime ? tc.startTime.toISOString() : 'N/A';
        const endTime = tc.endTime ? tc.endTime.toISOString() : 'N/A';
        const duration = (tc.duration / 1000).toFixed(2) + 's';
        
        return `"${testId}","${moduleVal}","${scenario}","${device}","${status}","${startTime}","${endTime}","${duration}"`;
      });
      fs.writeFileSync(csvPath, header + rows.join('\n') + '\n');
    } catch (csvError) {
      console.error(`[ExcelReporter] WARNING: Failed to write excel.csv: ${csvError.message}`);
    }
  }
}

// Export a single instance to share state across tests
module.exports = new ExcelReporter();
