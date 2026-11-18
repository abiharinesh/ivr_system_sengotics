const puppeteer = require('puppeteer');
const path = require('path');

async function generatePdf() {
  const browser = await puppeteer.launch({
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox'],
  });

  const page = await browser.newPage();
  const inputHtml = path.join(__dirname, '..', 'docs', 'STREET_LIGHT_TENDER_CONCEPT.html');
  const outputPdf = path.join(__dirname, '..', 'docs', 'STREET_LIGHT_TENDER_CONCEPT.pdf');

  const fileUrl = 'file://' + path.resolve(inputHtml).replace(/\\/g, '/');
  console.log('Navigating to:', fileUrl);
  await page.goto(fileUrl, { waitUntil: 'networkidle0', timeout: 30000 });

  await new Promise((r) => setTimeout(r, 1000));

  await page.pdf({
    path: outputPdf,
    format: 'A4',
    printBackground: true,
    margin: {
      top: '10mm',
      right: '10mm',
      bottom: '10mm',
      left: '10mm',
    },
    displayHeaderFooter: true,
    headerTemplate: '<div></div>',
    footerTemplate: `
      <div style="font-family: Arial, sans-serif; font-size: 8px; color: #64748b; width: 100%; display: flex; justify-content: space-between; padding: 0 10mm;">
        <span>LOCAL ADMINISTRATION DEPARTMENT • Smart Street Lighting System</span>
        <span>Page <span class="pageNumber"></span> of <span class="totalPages"></span></span>
      </div>
    `,
  });

  console.log('Successfully generated:', outputPdf);
  await browser.close();
}

generatePdf().catch((err) => {
  console.error('Error generating PDF:', err);
  process.exit(1);
});
