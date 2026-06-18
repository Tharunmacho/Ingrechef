const ExcelJS = require('exceljs');
const fs = require('fs');
const path = require('path');

async function convert() {
  const workbook = new ExcelJS.Workbook();
  await workbook.xlsx.readFile(path.join(__dirname, 'excel', 'Mobile_E2E_Report.xlsx'));
  
  for (const sheet of workbook.worksheets) {
    const csvPath = path.join(__dirname, 'excel', `${sheet.name.replace(/\s+/g, '_')}.csv`);
    const writeStream = fs.createWriteStream(csvPath);
    
    sheet.eachRow((row) => {
      const values = [];
      row.eachCell({ includeEmpty: true }, (cell) => {
        let val = cell.value;
        if (val && typeof val === 'object') {
          if (val.text) {
            val = val.text;
          } else if (val.result !== undefined) {
            val = val.result;
          } else {
            val = JSON.stringify(val);
          }
        }
        if (val === null || val === undefined) {
          val = '';
        }
        val = String(val).replace(/"/g, '""'); // escape double quotes
        values.push(`"${val}"`);
      });
      writeStream.write(values.join(',') + '\n');
    });
    
    writeStream.end();
    console.log(`Converted sheet ${sheet.name} to ${csvPath}`);
  }
}

convert().catch(console.error);
