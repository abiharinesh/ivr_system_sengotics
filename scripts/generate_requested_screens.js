const fetch = globalThis.fetch;
const fs = require('fs');
const path = require('path');

const url = 'https://stitch.googleapis.com/mcp';
const apiKey = 'AQ.Ab8RN6Izt1c1cOcSDExSjnR6folF1ED0dMFA9B3wYdriGOBffg';
const projectId = '8452091723434700175';

const screensToGenerate = [
  {
    name: 'complaints',
    deviceType: 'DESKTOP',
    prompt: 'Premium Panchayat Admin Complaint Management Screen. The design is modern, smooth, and extremely detailed. It features a split layout. The left column is a complaints list with search, filters (All, Pending, In Progress, Resolved, Rejected), and rich status badges. Each item card has a glassmorphic border, a colored indicator line, urgency tag, caller emotion tag, and date. The right section is a bento grid workspace for the selected complaint: 1. A premium audio player card with custom gradients, interactive play/pause controls, and an animated sound waveform. 2. A side-by-side transcript card displaying original native Tamil text (left) and English translation (right) with clean typography. 3. An AI insights card containing caller emotion analysis (frustrated/calm), confidence scores, and automatically parsed category. 4. A precise GIS location map card showing coordinates, landmarks, and nearest pole details. 5. Administrative control card with smooth dropdown menus to assign technicians (electricians/plumbers) and update status. Visual theme uses deep slate navy and soft white surfaces, vibrant primary blues, emerald green for resolved items, and amber warnings.'
  }
];

async function generateScreen(screen) {
  const payload = {
    jsonrpc: '2.0',
    method: 'tools/call',
    params: {
      name: 'generate_screen_from_text',
      arguments: {
        projectId: projectId,
        prompt: screen.prompt,
        deviceType: screen.deviceType
      }
    },
    id: 1
  };

  console.log(`\n--------------------------------------------------`);
  console.log(`Sending design request to Stitch for screen: "${screen.name}" (${screen.deviceType})...`);

  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'X-Goog-Api-Key': apiKey,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(payload)
  });

  console.log(`HTTP Status:`, response.status);
  const bodyText = await response.text();
  
  let result;
  try {
    result = JSON.parse(bodyText);
  } catch (e) {
    console.error(`Failed to parse response for "${screen.name}":`, bodyText.substring(0, 1000));
    return;
  }

  if (result.error) {
    console.error(`Error returned from server for "${screen.name}":`, result.error);
    return;
  }

  const outDir = path.join(__dirname, '..', 'artifacts', 'stitch_designs');
  if (!fs.existsSync(outDir)) {
    fs.mkdirSync(outDir, { recursive: true });
  }

  const outPath = path.join(outDir, `${screen.name}_result.json`);
  fs.writeFileSync(outPath, bodyText);
  console.log(`Saved generation response to ${outPath}`);

  // Download the HTML file if available
  try {
    const rpcResult = JSON.parse(result.result.content[0].text);
    const designScreen = rpcResult.outputComponents[0].design.screens.find(s => s.htmlCode && s.htmlCode.downloadUrl);
    if (designScreen) {
      const downloadUrl = designScreen.htmlCode.downloadUrl;
      console.log(`Downloading HTML code from:`, downloadUrl);
      const dlResponse = await fetch(downloadUrl, {
        headers: { 'X-Goog-Api-Key': apiKey }
      });
      if (dlResponse.ok) {
        const htmlText = await dlResponse.text();
        const htmlPath = path.join(outDir, `${screen.name}.html`);
        fs.writeFileSync(htmlPath, htmlText);
        console.log(`Saved HTML design to ${htmlPath}`);
      } else {
        console.error(`Failed to download HTML code: ${dlResponse.status}`);
      }
    } else {
      console.log(`No screen with htmlCode downloadUrl was returned in the design payload.`);
    }
  } catch (err) {
    console.error(`Error parsing design output or downloading HTML:`, err.message);
  }
}

async function main() {
  for (const screen of screensToGenerate) {
    try {
      await generateScreen(screen);
    } catch (e) {
      console.error(`Failed to generate screen "${screen.name}":`, e);
    }
    console.log(`Waiting 2 seconds before next request...`);
    await new Promise(r => setTimeout(r, 2000));
  }
  console.log(`\nAll requested screens generation process triggered.`);
}

main().catch(console.error);
