const test = require('node:test');
const assert = require('node:assert/strict');
const { createAuthRouter, hashPassword, validatePassword, users } = require('./src/auth');
const express = require('express');

function buildApp() {
  const app = express();
  app.use(express.json());
  app.use('/api/auth', createAuthRouter());
  return app;
}

function makeRequest(app, method, path, body) {
  return new Promise((resolve, reject) => {
    const server = app.listen(0, () => {
      const port = server.address().port;
      const http = require('node:http');
      const payload = JSON.stringify(body || {});
      const req = http.request({
        hostname: '127.0.0.1',
        port,
        path,
        method,
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(payload),
        },
      }, (res) => {
        const chunks = [];
        res.on('data', (chunk) => chunks.push(chunk));
        res.on('end', () => {
          server.close();
          resolve({
            status: res.statusCode,
            body: JSON.parse(Buffer.concat(chunks).toString() || '{}'),
          });
        });
      });

      req.on('error', (error) => {
        server.close();
        reject(error);
      });

      req.write(payload);
      req.end();
    });
  });
}

test('validatePassword requires a strong password', () => {
  assert.equal(validatePassword('short'), 'Password must be at least 8 characters long.');
  assert.equal(validatePassword('password1'), 'Password must include uppercase, lowercase, and a number.');
  assert.equal(validatePassword('StrongPass1'), '');
});

test('signup creates a farmer user and hashes the password', async () => {
  const app = buildApp();
  const response = await makeRequest(app, 'POST', '/api/auth/signup', {
    name: 'Farmer User',
    email: 'farmer@example.com',
    password: 'StrongPass1',
    role: 'farmer',
  });

  assert.equal(response.status, 201);
  assert.equal(response.body.user.email, 'farmer@example.com');
  assert.equal(response.body.user.role, 'farmer');
  assert.ok(users.get('farmer@example.com').passwordHash);
  assert.equal(users.get('farmer@example.com').passwordHash, hashPassword('StrongPass1'));
  assert.notEqual(users.get('farmer@example.com').passwordHash, 'StrongPass1');
});

test('signin rejects invalid credentials', async () => {
  const app = buildApp();
  const response = await makeRequest(app, 'POST', '/api/auth/signin', {
    email: 'missing@example.com',
    password: 'StrongPass1',
  });

  assert.equal(response.status, 401);
  assert.equal(response.body.message, 'Invalid email or password.');
});

