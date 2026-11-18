const puppeteer = require('puppeteer');
const path = require('path');
const fs = require('fs');

async function convertHtmlToPdf() {
  console.log('Launching headless browser...');
  const browser = await puppeteer.launch({
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox'],
  });

  const filesToConvert = [
    {
      input: path.join(__dirname, '..', 'docs', 'TENDER_CONCEPT_ELECTRICAL_POLE_MODULE.html'),
      output: path.join(__dirname, '..', 'docs', 'TENDER_CONCEPT_ELECTRICAL_POLE_MODULE.pdf'),
      title: 'Electrical Pole Module Tender Concept',
    },
    {
      input: path.join(__dirname, '..', 'docs', 'TENDER_CONCEPT_WATER_SUPPLY_MODULE.html'),
      output: path.join(__dirname, '..', 'docs', 'TENDER_CONCEPT_WATER_SUPPLY_MODULE.pdf'),
      title: 'Water Supply Module Tender Concept',
    },
    {
      input: path.join(__dirname, '..', 'docs', 'QUOTATION_QR_POLE_INSTALLATION.html'),
      output: path.join(__dirname, '..', 'docs', 'QUOTATION_QR_POLE_INSTALLATION.pdf'),
      title: 'QR Pole Installation Commercial Quotation',
    },
    {
      input: path.join(__dirname, '..', 'docs', 'SENGOTICS_PROPOSAL_LETTER.html'),
      output: path.join(__dirname, '..', 'docs', 'SENGOTICS_PROPOSAL_LETTER.pdf'),
      title: 'Sengotics Official Proposal Letter',
    },
  ];

  for (const item of filesToConvert) {
    if (!fs.existsSync(item.input)) {
      console.warn(`File does not exist: ${item.input}, skipping.`);
      continue;
    }

    console.log(`Generating PDF for: ${item.title}...`);
    const page = await browser.newPage();
    const fileUrl = 'file://' + path.resolve(item.input).replace(/\\/g, '/');
    
    await page.goto(fileUrl, { waitUntil: 'networkidle0', timeout: 60000 });
    
    // Allow extra 1 second for web fonts to render crisply
    await new Promise((resolve) => setTimeout(resolve, 1000));

    let targetPath = item.output;
    try {
      await page.pdf({
        path: targetPath,
        format: 'A4',
        printBackground: true,
        margin: {
          top: '12mm',
          right: '12mm',
          bottom: '12mm',
          left: '12mm',
        },
        displayHeaderFooter: true,
        headerTemplate: '<div></div>',
        footerTemplate: `
          <div style="font-family: Arial, sans-serif; font-size: 8px; color: #64748b; width: 100%; display: flex; justify-content: space-between; padding: 0 15mm;">
            <span>SENGOTICS • Smart Governance Systems</span>
            <span>Page <span class="pageNumber"></span> of <span class="totalPages"></span></span>
          </div>
        `,
      });
      console.log(`Successfully generated: ${targetPath}`);
    } catch (err) {
      if (err.code === 'EBUSY') {
        targetPath = item.output.replace(/\.pdf$/, '_UPDATED.pdf');
        console.warn(`Original file was locked by an active viewer. Saving to: ${targetPath}`);
        await page.pdf({
          path: targetPath,
          format: 'A4',
          printBackground: true,
          margin: {
            top: '12mm',
            right: '12mm',
            bottom: '12mm',
            left: '12mm',
          },
          displayHeaderFooter: true,
          headerTemplate: '<div></div>',
          footerTemplate: `
            <div style="font-family: Arial, sans-serif; font-size: 8px; color: #64748b; width: 100%; display: flex; justify-content: space-between; padding: 0 15mm;">
              <span>SENGOTICS • Smart Governance Systems</span>
              <span>Page <span class="pageNumber"></span> of <span class="totalPages"></span></span>
            </div>
          `,
        });
        console.log(`Successfully generated fallback: ${targetPath}`);
      } else {
        throw err;
      }
    }

    await page.close();
  }

  await browser.close();
  console.log('All PDFs generated successfully!');
}

convertHtmlToPdf().catch((err) => {
  console.error('Error generating PDFs:', err);
  process.exit(1);
});
