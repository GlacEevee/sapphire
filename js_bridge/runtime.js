// runtime.js — Node.js side of the Sapphire JS bridge
// Receives JSON calls on stdin, responds with JSON on stdout

const readline = require('readline');

const packages = {
  web:    tryRequire('./packages/web'),
  ui:     tryRequire('./packages/ui'),
  canvas: tryRequire('./packages/canvas'),
};

function tryRequire(path) {
  try { return require(path); } catch { return null; }
}

const rl = readline.createInterface({ input: process.stdin, terminal: false });

rl.on('line', (line) => {
  let req;
  try { req = JSON.parse(line); } catch {
    respond(null, 'Invalid JSON');
    return;
  }

  const { package: pkg, fn, args } = req;
  const mod = packages[pkg];

  if (!mod) {
    respond(null, `Package '${pkg}' not available. Install with: npm install (in js_bridge/)`);
    return;
  }

  if (typeof mod[fn] !== 'function') {
    respond(null, `Function '${fn}' not found in package '${pkg}'`);
    return;
  }

  try {
    const result = mod[fn](...(args || []));
    if (result && typeof result.then === 'function') {
      result.then(r => respond(r)).catch(e => respond(null, e.message));
    } else {
      respond(result);
    }
  } catch (e) {
    respond(null, e.message);
  }
});

function respond(result, error = null) {
  process.stdout.write(JSON.stringify({ result, error }) + '\n');
}
