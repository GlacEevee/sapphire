// web.js — Simple web server package for Sapphire JS bridge
let express, app, server, wss;

function create(port = 3000) {
  express = require('express');
  const { WebSocketServer } = require('ws');
  app    = express();
  app.use(express.json());
  server = require('http').createServer(app);
  wss    = new WebSocketServer({ server });
  return { port };
}

function get(path, body) {
  if (!app) return false;
  app.get(path, (req, res) => res.send(body));
  return true;
}

function post(path, handler) {
  if (!app) return false;
  app.post(path, (req, res) => {
    const result = handler(req.body);
    res.json(result);
  });
  return true;
}

function serve_static(dir) {
  if (!app) return false;
  app.use(express.static(dir));
  return true;
}

function listen(port = 3000) {
  if (!server) return false;
  server.listen(port);
  return true;
}

function stop() {
  server?.close();
  return true;
}

module.exports = { create, get, post, serve_static, listen, stop };
