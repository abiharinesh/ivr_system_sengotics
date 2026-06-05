const fetch = require('node:crypto') ? globalThis.fetch : null;
const fs = require('fs');
const path = require('path');

const url = 'https://stitch.googleapis.com/mcp';
const apiKey = 'AQ.Ab8RN6Izt1c1cOcSDExSjnR6folF1ED0dMFA9B3wYdriGOBffg';
const projectId = '8452091723434700175';

const screensToGenerate = [
  {
    name: 'complaints',
    prompt: 'Panchayat Admin Complaint Management Screen for Ooraatchi GIS platform. It is a dashboard and detail workspace showing infrastructure complaints (e.g. Street Light Faults). It includes a list of active complaints with search, filters (All, Pending, In Progress, Resolved, Rejected), and quick status toggles. Selecting a complaint reveals a bento detail panel containing: 1. A premium audio player card with waveform to play citizen complaint voice calls, 2. Side-by-side original native Tamil transcript and English translation card, 3. AI caller emotion analysis (Caller Emotion: Frustrated, urgency: High), 4. A map showing coordinates of the affected electric pole, 5. Administrative Quick Actions card to assign an electrician or plumber or modify the status. The layout is clean and corporate modern, utilizing Public Sans and Metropolis, with deep navy colors for headers, green for active status, and light backgrounds.'
  },
  {
    name: 'poles',
    prompt: 'Panchayat Admin Electric Pole Inventory and GIS Management Screen for Ooraatchi GIS platform. Designed for tracking infrastructure assets. It features: 1. A split map and list layout. The map displays individual electric poles, colored by their status (active green, issues warning amber). 2. Left list displays electric poles with database IDs, keypad IDs, a list of landmarks (e.g., near temple, bus stop), coordinates, and a count of complaints linked to that pole. 3. Top action bar with "Add Pole" button showing form fields for pole number, keypad ID, location inputs, and landmarks, and options to edit or delete existing poles. Standard corporate modern Slate/Navy visual design.'
  },
  {
    name: 'electricians',
    prompt: 'Panchayat Admin Electrician Staff Management and resolved jobs Analytics Screen for Ooraatchi GIS. It displays: 1. A list of active electricians in the panchayat, with their contact numbers and registered emails. 2. Periodic performance stats (This Month, Last 3 Months) tracking resolved vs assigned complaints and average resolution time. 3. ZIP export button to download all resolved job history including photo proofs of work. 4. Dialog to add a new electrician with email, password, and contact phone number. Corporate modern theme.'
  },
  {
    name: 'plumbers',
    prompt: 'Panchayat Admin Plumber Staff Management and resolved plumbing jobs Analytics Screen for Ooraatchi GIS. It mirrors the electrician layout for water infrastructure plumbers. It displays: 1. A list of active plumbers in the panchayat, showing emails, phones, and current active jobs. 2. Periodic performance stats (This Month, Last 3 Months) tracking assigned vs resolved water grid leaks. 3. ZIP export button to download all resolved plumbing job history and EXIF geo-tagged image verification reports. 4. Action to create a new plumber profile with email, password, and phone. Corporate modern style.'
  },
  {
    name: 'pipeline_grid',
    prompt: 'Panchayat Admin Water Pipeline Grid and Leak Monitor Screen for Ooraatchi GIS. Features: 1. An interactive GIS satellite map rendering water pipeline path lines (GeoJSON LineString) and water supply tanks (overhead reservoirs, borewell pumps). 2. Side panel showing a list of pipeline sections, diameters in mm, materials (PVC, HDPE, Cast Iron), and current status (active green, leak alert warning amber). 3. Real-time sensor logs chart displaying flow rate in LPS (Liters Per Second) and water pressure in bars. 4. Dialog to "Assign Plumber" when a leak alert is clicked, prompting a list of available plumbers to dispatch for instant maintenance. Clean, professional data-dense UI.'
  },
  {
    name: 'zone_management',
    prompt: 'Panchayat Admin Ward and Zone Boundary GIS Management Screen for Ooraatchi GIS. Features: 1. Interactive map rendering custom ward polygons with customizable boundary lines and transparency opacities. 2. Sidebar to search for administrative places and lookup their boundaries using GIS databases. 3. Toolbar for drawing custom polygons directly on the map, with Undo, Clear, and Save options. 4. Save Zone dialog to enter zone name, color hex code, opacity value, and place list. Structured corporate layout with precise, low-contrast shadows and slate/navy borders.'
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
        deviceType: 'DESKTOP'
      }
    },
    id: 1
  };

  console.log(`\n--------------------------------------------------`);
  console.log(`Sending design request to Stitch for screen: "${screen.name}"...`);

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
    // Add a small pause between requests to prevent overwhelming the server
    console.log(`Waiting 2 seconds before next request...`);
    await new Promise(r => setTimeout(r, 2000));
  }
  console.log(`\nAll screens generation process triggered.`);
}

main().catch(console.error);
