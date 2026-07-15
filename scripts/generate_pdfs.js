const fs = require('fs');
const path = require('path');
const { marked } = require('marked');
const puppeteer = require('puppeteer');

// Paths
const docsDir = path.join(__dirname, '..', 'docs');
const units = [
    { num: 1, name: 'Unit 1: Introduction & C Basics' },
    { num: 2, name: 'Unit 2: Control Flow, Arrays, Functions, Pointers & Structures' },
    { num: 3, name: 'Unit 3: Algorithms, Data Structures & Arrays' }
];

// Helper to pre-process GitHub Alerts
function preProcessMarkdown(text) {
    // Convert > [!NOTE], > [!IMPORTANT], etc.
    return text.replace(/^>\s*\[!(NOTE|IMPORTANT|WARNING|CAUTION|TIP)\]\s*\n((?:>.*\n?)*)/gim, (match, type, content) => {
        const cleanContent = content.replace(/^>\s?/gm, '');
        return `<div class="alert alert-${type.toLowerCase()}"><strong>${type}:</strong> ${cleanContent}</div>\n`;
    });
}

// Helper to post-process HTML (Mermaid code blocks)
function postProcessHtml(html) {
    return html.replace(/<pre><code class="language-mermaid">([\s\S]*?)<\/code><\/pre>/g, (match, code) => {
        // Decode HTML entities
        const decoded = code
            .replace(/&lt;/g, '<')
            .replace(/&gt;/g, '>')
            .replace(/&amp;/g, '&')
            .replace(/&quot;/g, '"')
            .replace(/&#39;/g, "'");
        return `<pre class="mermaid">${decoded}</pre>`;
    });
}

// HTML Skeleton with styles, KaTeX, and Mermaid
const getHtmlWrapper = (title, content) => `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>${title}</title>
    <!-- CSS styles for high-quality printing -->
    <style>
        @import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&family=Fira+Code:wght@400;500&display=swap');
        
        body {
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            color: #2d3748;
            line-height: 1.6;
            font-size: 11pt;
            margin: 0;
            padding: 10px;
        }
        
        h1, h2, h3, h4, h5, h6 {
            color: #1a365d;
            font-weight: 700;
            page-break-after: avoid;
        }

        h1 {
            font-size: 22pt;
            border-bottom: 2px solid #2b6cb0;
            padding-bottom: 8px;
            margin-top: 0;
            margin-bottom: 20px;
        }

        .unit-title {
            page-break-before: avoid;
        }

        h2 {
            font-size: 16pt;
            border-bottom: 1px solid #e2e8f0;
            padding-bottom: 5px;
            margin-top: 30px;
            margin-bottom: 15px;
            page-break-before: always;
        }

        h3 {
            font-size: 13pt;
            margin-top: 20px;
            margin-bottom: 10px;
        }

        p {
            margin-bottom: 15px;
            text-align: justify;
        }

        /* Lists */
        ul, ol {
            margin-bottom: 20px;
            padding-left: 25px;
        }

        li {
            margin-bottom: 5px;
        }

        /* Codes */
        code {
            font-family: 'Fira Code', Consolas, Monaco, monospace;
            background-color: #edf2f7;
            color: #c53030;
            padding: 2px 6px;
            border-radius: 4px;
            font-size: 9.5pt;
        }

        pre {
            background-color: #1a202c;
            color: #f7fafc;
            padding: 15px;
            border-radius: 6px;
            overflow: auto;
            margin-bottom: 20px;
            page-break-inside: avoid;
            border-left: 4px solid #3182ce;
        }

        pre code {
            background-color: transparent;
            color: inherit;
            padding: 0;
            font-size: 9pt;
        }

        /* Tables */
        table {
            width: 100%;
            border-collapse: collapse;
            margin-bottom: 25px;
            page-break-inside: avoid;
        }

        th, td {
            padding: 10px 12px;
            text-align: left;
            border-bottom: 1px solid #e2e8f0;
            font-size: 10pt;
        }

        th {
            background-color: #2b6cb0;
            color: white;
            font-weight: 600;
        }

        tr:nth-child(even) {
            background-color: #f7fafc;
        }

        /* Blockquotes */
        blockquote {
            border-left: 4px solid #718096;
            background-color: #f7fafc;
            margin: 15px 0;
            padding: 8px 16px;
            color: #4a5568;
            page-break-inside: avoid;
        }

        blockquote p {
            margin: 0;
        }

        /* Alerts */
        .alert {
            padding: 12px 16px;
            margin: 20px 0;
            border-left: 4px solid;
            border-radius: 4px;
            page-break-inside: avoid;
        }

        .alert-note {
            background-color: #ebf8ff;
            border-color: #3182ce;
            color: #2b6cb0;
        }

        .alert-important {
            background-color: #f0fff4;
            border-color: #38a169;
            color: #276749;
        }

        .alert-warning {
            background-color: #fffaf0;
            border-color: #dd6b20;
            color: #9c4221;
        }

        .alert-caution {
            background-color: #fff5f5;
            border-color: #e53e3e;
            color: #9b2c2c;
        }

        .alert-tip {
            background-color: #faf5ff;
            border-color: #805ad5;
            color: #553c9a;
        }

        /* Mermaid diagram style */
        .mermaid {
            display: flex;
            justify-content: center;
            margin: 20px 0;
            page-break-inside: avoid;
            background: #fff;
            padding: 10px;
            border: 1px solid #e2e8f0;
            border-radius: 6px;
        }

        .page-break {
            page-break-before: always;
        }
    </style>

    <!-- KaTeX for math styling -->
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.8/dist/katex.min.css">
    <script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.8/dist/katex.min.js"></script>
    <script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.8/dist/contrib/auto-render.min.js" onload="renderMathInElement(document.body);"></script>

    <!-- Mermaid for diagram styling -->
    <script type="module">
        import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.esm.min.mjs';
        mermaid.initialize({ 
            startOnLoad: true,
            theme: 'default',
            securityLevel: 'loose'
        });
    </script>
</head>
<body>
    ${content}
</body>
</html>
`;

async function generatePDFs() {
    console.log('Launching browser with Puppeteer...');
    const browser = await puppeteer.launch({
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });

    for (const unit of units) {
        const mdPath = path.join(docsDir, `unit_${unit.num}_notes.md`);
        const tempHtmlPath = path.join(docsDir, `temp_unit_${unit.num}.html`);
        const pdfPath = path.join(docsDir, `unit_${unit.num}_notes.pdf`);

        console.log(`Processing Unit ${unit.num}...`);
        
        if (!fs.existsSync(mdPath)) {
            console.error(`File not found: ${mdPath}`);
            continue;
        }

        let markdownContent = fs.readFileSync(mdPath, 'utf-8');
        
        // 1. Pre-process alerts
        markdownContent = preProcessMarkdown(markdownContent);
        
        // 2. Parse Markdown
        let htmlContent = marked.parse(markdownContent);
        
        // 3. Post-process (Mermaid block adjustments)
        htmlContent = postProcessHtml(htmlContent);

        // 4. Wrap with skeleton
        const finalHtml = getHtmlWrapper(unit.name, htmlContent);
        fs.writeFileSync(tempHtmlPath, finalHtml, 'utf-8');

        // 5. Render via Puppeteer
        const page = await browser.newPage();
        
        // Load the local HTML file
        const fileUrl = `file:///${path.resolve(tempHtmlPath).replace(/\\/g, '/')}`;
        await page.goto(fileUrl, { waitUntil: 'networkidle0' });

        // Wait a few seconds for KaTeX and Mermaid to render completely
        console.log('Waiting for diagrams and equations to render...');
        await new Promise(r => setTimeout(r, 4000));

        // PDF Print configuration
        console.log('Printing to PDF...');
        await page.pdf({
            path: pdfPath,
            format: 'A4',
            margin: {
                top: '20mm',
                bottom: '20mm',
                left: '18mm',
                right: '18mm'
            },
            displayHeaderFooter: true,
            headerTemplate: `
                <div style="font-size: 8pt; font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif; color: #a0aec0; display: flex; justify-content: space-between; width: 100%; padding-left: 18mm; padding-right: 18mm; border-bottom: 1px solid #e2e8f0; padding-bottom: 3px;">
                    <span>23CYUC101 - Data Structures Using C Programming</span>
                    <span>Syllabus Notes</span>
                </div>`,
            footerTemplate: `
                <div style="font-size: 8pt; font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif; color: #a0aec0; display: flex; justify-content: space-between; width: 100%; padding-left: 18mm; padding-right: 18mm; border-top: 1px solid #e2e8f0; padding-top: 3px;">
                    <span>${unit.name}</span>
                    <span>Page <span class="pageNumber"></span> of <span class="totalPages"></span></span>
                </div>`,
            preferCSSPageSize: true
        });

        await page.close();
        
        // Clean up temporary HTML file
        fs.unlinkSync(tempHtmlPath);
        console.log(`Successfully generated: docs/unit_${unit.num}_notes.pdf`);
    }

    await browser.close();
    console.log('All PDFs generated successfully!');
}

generatePDFs().catch(err => {
    console.error('Error generating PDFs:', err);
    process.exit(1);
});
