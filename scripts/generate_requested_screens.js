const fetch = globalThis.fetch;
const fs = require('fs');
const path = require('path');

const url = 'https://stitch.googleapis.com/mcp';
const apiKey = 'AQ.Ab8RN6Izt1c1cOcSDExSjnR6folF1ED0dMFA9B3wYdriGOBffg';
const projectId = '8452091723434700175';

const screensToGenerate = [
  {
    name: 'pipeline_tap_capture',
    deviceType: 'MOBILE',
    prompt: 'Field Agent Pipeline & Tap Capture Mobile Screen for Ooraatchi GIS platform. Designed for field agents capturing data on mobile viewports. It features: 1. A top interactive map component displaying current location coordinates, accuracy indicator, and pipeline paths. 2. A multi-step form to record new pipeline layouts or household tap connections, including connection type selector (Household, Public Tap, Main Pipeline), pipe material (PVC, HDPE, Cast Iron), diameter (in mm), GPS coordinates (auto-filled), and photo upload section with camera preview. 3. Sync status panel tracking captured items that are pending sync (offline-first capability) with clean action to "Sync connection". 4. Standard corporate modern Slate/Navy visual design with Emerald Green accents, using Metropolis and Public Sans.'
  },
  {
    name: 'infrastructure_approval',
    deviceType: 'DESKTOP',
    prompt: 'Panchayat Admin Infrastructure Approval Workspace for Ooraatchi GIS platform. Designed for desktop review of field-captured data. It features: 1. A top metrics dashboard displaying Pending approvals, Approved count, Rejected count, and Sync status. 2. A split map and details layout. The left column lists pending approval tickets (e.g. "New Household Tap - Ward 3", "HDPE Pipe Segment - Ward 1") with details (date, agent name, urgency status). 3. The right column displays the selected ticket\'s detail panel, including: (a) Leaflet/GIS map preview highlighting the geo-tagged coordinates of the proposed pipeline/tap, (b) EXIF metadata card showing device model, altitude, precision, timestamp, (c) Image verification proof card displaying the photo uploaded by the agent, (d) Approval/Rejection controls with status text comments input and "Approve Infrastructure" and "Reject" buttons. Corporate modern slate theme with Emerald Green for approvals and warning amber for pending items.'
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
