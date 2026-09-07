const jwt = require('jsonwebtoken');

// সরাসরি env থেকে নেওয়া হলো, undefined হওয়ার কোনো সুযোগ নেই
const JWT_SECRET = process.env.JWT_SECRET || 'smart_farmer_super_secret_jwt_key_2026';

// Middleware to verify JWT token
const authenticate = (req, res, next) => {
  const authHeader = req.header('Authorization');

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Access denied. No token provided.' });
  }

  const token = authHeader.split(' ')[1];

  try {
    const verified = jwt.verify(token, JWT_SECRET);
    req.user = verified;
    next();
  } catch (error) {
    console.error('JWT Verification Error:', error.message);
    res.status(401).json({ error: 'Invalid or expired token.' });
  }
};

// Middleware to restrict access to Admins only
const authorizeAdmin = (req, res, next) => {
  if (req.user.role !== 'admin') {
    return res.status(403).json({ error: 'Access denied. Admin privileges required.' });
  }
  next();
};

module.exports = { authenticate, authorizeAdmin };