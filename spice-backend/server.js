const express = require('express');
const { exec } = require('child_process');
const fs = require('fs');
const path = require('path');
const app = express();

const buildPath = path.join(__dirname, 'flutter_web');
app.use(express.static(buildPath));


app.use('/plots', express.static(path.join(__dirname, 'plots')));


app.get('/', (req, res) => {
  res.sendFile(path.join(buildPath, 'index.html'));
});

const port = 3000;

app.use(express.json());
app.use((req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  next();
});

app.post('/simulateop', (req, res) => {
  let netlistContent = req.body.content;
  if (!netlistContent || netlistContent.trim() === '') {
    return res.status(400).send("❌ No netlist provided");
  }

 
  const lines = netlistContent.split('\n');
  const endIndex = lines.findIndex(l => l.trim().toLowerCase() === '.end');
  if (endIndex !== -1) {
    lines.splice(endIndex, 0, '.probe all');
  } else {
    lines.push('.probe all', '.end');
  }
  netlistContent = lines.join('\n');

  const filePath = path.join(__dirname, 'temp_netlist.cir');
  fs.writeFileSync(filePath, netlistContent);

  exec(`ngspice -b ${filePath}`, (err, stdout, stderr) => {
    if (err) {
      console.error("❌ NGSpice error:", stderr);
      return res.status(500).json({ error: "Simulation failed" });
    }

    const voltages = {};
    const currents = {};

    const voltageRegex = /V\((\d+)\)\s+([-+\deE.]+)/;
    const currentRegex =  /^\s*([a-zA-Z]+\d+(?::[a-z])?)#branch\s+([-+\deE.]+)/i;

    for (const line of stdout.split('\n')) {
      const vMatch = voltageRegex.exec(line);
      if (vMatch) {
        const node = vMatch[1];
        const value = parseFloat(vMatch[2]);
        voltages[`node_${node}`] = value;
      }

      const iMatch = currentRegex.exec(line);
      if (iMatch) {
        const label = iMatch[1].toUpperCase();  // Normalize: R1, D0, V2, etc.
        const current = parseFloat(iMatch[2]);
        currents[label] = current;
        console.log(`🔌 Captured ${label} = ${current} A`);
      }
    }

    res.json({
      voltages,
      currents,
      result: [
        ...Object.entries(voltages).map(([k, v]) => `${k}: ${v} V`),
        ...Object.entries(currents).map(([k, v]) => `Current through ${k}: ${v} A`)
      ]
    });
  });
});

function createGnuplotScriptFromWrdata(wrdataLine, outputFile = 'plot_script.gnuplot') {
  const fs = require('fs');
  const path = require('path');

  const lines = [];
  let counter2 = 2;

  const plotsDir = path.join(__dirname, 'plots');

  // ✅ Clear contents of plots folder before doing anything
  if (fs.existsSync(plotsDir)) {
    fs.readdirSync(plotsDir).forEach(file => {
      const fullPath = path.join(plotsDir, file);
      if (fs.lstatSync(fullPath).isFile()) {
        fs.unlinkSync(fullPath);
      }
    });
  } else {
    fs.mkdirSync(plotsDir);
  }

  lines.push('set terminal pngcairo size 800,600');

  // 🧠 Extract v(...) matches
  const matches = wrdataLine.match(/v\([^)]+\)/gi);
  if (!matches) {
    console.warn("⚠ No voltage expressions found in wrdata line.");
    return;
  }

  // 🧠 Extract numbers from comment part after '*'
  const commentParts = wrdataLine.split('*');
  let imageIndices = [];

  if (commentParts.length > 1) {
    imageIndices = commentParts[1]
      .trim()
      .split(/\s+/)
      .map(num => num.trim())
      .filter(num => /^\d+$/.test(num));
  }

  if (imageIndices.length !== matches.length) {
    console.warn("⚠ Mismatch between number of voltage expressions and comment image indices. Using default numbering.");
    imageIndices = matches.map((_, i) => i); // fallback
  }

  // 🖼️ Generate plot commands
  for (let i = 0; i < matches.length; i++) {
    const vExpression = matches[i];
    const fileIndex = imageIndices[i];
    const titleLabel = vExpression.replace(/[v()]/gi, '').trim();

    lines.push(`\nset output 'plots/v_${fileIndex}.png'`);
    lines.push(`set title "v ${titleLabel}"`);
    lines.push(`set xlabel "Time (s)"`);
    lines.push(`set ylabel "Voltage (V)"`);
    lines.push(`set grid`);
    lines.push(`plot "rc_data.txt" using 1:${counter2} with lines title "V(out)"`);

    counter2 += 2;
  }

  fs.writeFileSync(path.join(__dirname, outputFile), lines.join('\n'));
  console.log(`✅ Gnuplot script written to ${outputFile}`);
}





app.post('/simulatetran', (req, res) => {
  let netlistContent = req.body.content;
  if (!netlistContent || netlistContent.trim() === '') {
    return res.status(400).send("❌ No netlist provided");
  }

  console.log(netlistContent);
  const filePath = path.join(__dirname, 'temp_netlist.cir');
  fs.writeFileSync(filePath, netlistContent);

  // 🧠 Extract the wrdata line from netlist content
  const wrdataLine = netlistContent
    .split('\n')
    .find(line => line.trim().toLowerCase().startsWith('wrdata'));

  // 🛠 Call Gnuplot script generator if wrdata line exists
  if (wrdataLine) {
    createGnuplotScriptFromWrdata(wrdataLine.trim());
  } else {
    console.warn("⚠ No 'wrdata' line found in netlist — skipping Gnuplot script generation.");
  }

  exec(`ngspice -b ${filePath}`, (err, stdout, stderr) => {
    if (err) {
      console.error("❌ NGSpice error:", stderr);
      return res.status(500).json({ error: "Simulation failed" });
    }

    const voltages = {};
    const currents = {};

    const voltageRegex = /V\((\d+)\)\s+([-+\deE.]+)/;
    const currentRegex = /^\s*([a-zA-Z]+\d+(?::[a-z])?)#branch\s+([-+\deE.]+)/i;

    for (const line of stdout.split('\n')) {
      const vMatch = voltageRegex.exec(line);
      if (vMatch) {
        const node = vMatch[1];
        const value = parseFloat(vMatch[2]);
        voltages[`node_${node}`] = value;
      }

      const iMatch = currentRegex.exec(line);
      if (iMatch) {
        const label = iMatch[1].toUpperCase();
        const current = parseFloat(iMatch[2]);
        currents[label] = current;
        console.log(`🔌 Captured ${label} = ${current} A`);
      }
    }

    // ➕ Run gnuplot script AFTER simulation
    const gnuplotScriptPath = path.join(__dirname, 'plot_script.gnuplot');
    exec(`gnuplot "${gnuplotScriptPath}"`, (gnuErr, gnuStdout, gnuStderr) => {
      if (gnuErr) {
        console.error("❌ Gnuplot execution failed:", gnuStderr);
        // Optionally return 200 with warning if plot fails
        return res.status(200).json({
          voltages,
          currents,
          result: [
            ...Object.entries(voltages).map(([k, v]) => `${k}: ${v} V`),
            ...Object.entries(currents).map(([k, v]) => `Current through ${k}: ${v} A`)
          ],
          warning: "Simulation OK, but plot generation failed."
        });
      }

      console.log("📊 Gnuplot finished successfully");

const plotsDir = path.join(__dirname, 'plots');
const pngUrls = fs.readdirSync(plotsDir)
  .filter(name => /^v_\d+\.png$/.test(name))  // Match files like v_7.png
  .map(name => `/plots/${name}`);             // Web-accessible path

res.json({
  voltages,
  currents,
  result: [
    ...Object.entries(voltages).map(([k, v]) => `${k}: ${v} V`),
    ...Object.entries(currents).map(([k, v]) => `Current through ${k}: ${v} A`)
  ],
  plots: pngUrls
});

});
  });
});


app.post('/runscam', (req, res) => {
  const resultPath = path.join(__dirname, 'mna_results.txt');

  exec('python scam_patched_fixed.py', (err, stdout, stderr) => {
    if (err) {
      console.error('❌ Python script execution failed:', stderr);
      return res.status(500).json({ error: 'Python script execution failed' });
    }

    // Wait a brief moment to ensure the file is written (can be fine-tuned or replaced with fs.watch if needed)
    setTimeout(() => {
      if (!fs.existsSync(resultPath)) {
        return res.status(404).json({ error: 'Result file not found' });
      }

      const resultText = fs.readFileSync(resultPath, 'utf8');
      res.json({ result: resultText.trim() });
    }, 100); // Optional small delay
  });
});

app.listen(port, () => {
  console.log(`🚀 Server running at http://localhost:${port}`);
});

