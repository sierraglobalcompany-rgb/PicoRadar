'use strict';

const fs = require('fs');
const http = require('http');
const https = require('https');

const [httpsPort, backendPort, certPath, keyPath] = process.argv.slice(2);
const username = process.env.PICORADAR_TEST_BASIC_USER;
const password = process.env.PICORADAR_TEST_BASIC_PASSWORD;
const expected = `Basic ${Buffer.from(`${username}:${password}`).toString('base64')}`;

const server = https.createServer({
  cert: fs.readFileSync(certPath),
  key: fs.readFileSync(keyPath),
}, (request, response) => {
  if (request.headers.authorization !== expected) {
    response.writeHead(401, {
      'WWW-Authenticate': 'Basic realm="PicoRadar local staging"',
      'Content-Type': 'text/plain; charset=utf-8',
    });
    response.end('Private staging');
    return;
  }

  const headers = { ...request.headers };
  const upstream = http.request({
    hostname: '127.0.0.1',
    port: Number(backendPort),
    path: request.url,
    method: request.method,
    headers,
  }, (upstreamResponse) => {
    const responseHeaders = { ...upstreamResponse.headers };
    if (responseHeaders.location) {
      try {
        const location = new URL(responseHeaders.location);
        if (location.hostname === 'picoradar.bodegadigitalmedellin.com') {
          responseHeaders.location = `https://127.0.0.1:${httpsPort}${location.pathname}${location.search}${location.hash}`;
        }
      } catch {
        // Relative redirects already remain inside the local fixture.
      }
    }
    response.writeHead(upstreamResponse.statusCode ?? 502, responseHeaders);
    upstreamResponse.pipe(response);
  });
  upstream.on('error', () => {
    if (!response.headersSent) response.writeHead(502);
    response.end('Upstream unavailable');
  });
  request.pipe(upstream);
});

server.listen(Number(httpsPort), '127.0.0.1', () => {
  process.stdout.write('READY\n');
});
