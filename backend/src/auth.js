const express = require("express");
const crypto = require("crypto");

const USER_ROLES = {
  FARMER: "farmer",
  ADMIN: "admin",
};

const users = new Map();

function normalizeEmail(email) {
  return String(email || "").trim().toLowerCase();
}

function validatePassword(password) {
  if (!password || typeof password !== "string") {
    return "Password is required.";
  }

  if (password.length < 8) {
    return "Password must be at least 8 characters long.";
  }

  if (!/[A-Z]/.test(password) || !/[a-z]/.test(password) || !/[0-9]/.test(password)) {
    return "Password must include uppercase, lowercase, and a number.";
  }

  return "";
}

function hashPassword(password) {
  return crypto.createHash("sha256").update(password).digest("hex");
}

function createAuthRouter() {
  const router = express.Router();

  router.post("/signup", (req, res) => {
    const { name, email, password, role } = req.body || {};

    if (!name || !String(name).trim()) {
      return res.status(400).json({ message: "Name is required." });
    }

    const normalizedEmail = normalizeEmail(email);
    if (!normalizedEmail || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(normalizedEmail)) {
      return res.status(400).json({ message: "Valid email is required." });
    }

    const passwordError = validatePassword(password);
    if (passwordError) {
      return res.status(400).json({ message: passwordError });
    }

    const selectedRole = role === USER_ROLES.ADMIN ? USER_ROLES.ADMIN : USER_ROLES.FARMER;
    if (users.has(normalizedEmail)) {
      return res.status(409).json({ message: "An account with this email already exists." });
    }

    const user = {
      id: crypto.randomUUID(),
      name: String(name).trim(),
      email: normalizedEmail,
      passwordHash: hashPassword(password),
      role: selectedRole,
    };

    users.set(normalizedEmail, user);

    return res.status(201).json({
      message: "Account created successfully.",
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        role: user.role,
      },
    });
  });

  router.post("/signin", (req, res) => {
    const { email, password } = req.body || {};
    const normalizedEmail = normalizeEmail(email);

    if (!normalizedEmail || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(normalizedEmail)) {
      return res.status(400).json({ message: "Valid email is required." });
    }

    const passwordError = validatePassword(password);
    if (passwordError) {
      return res.status(400).json({ message: passwordError });
    }

    const user = users.get(normalizedEmail);
    if (!user) {
      return res.status(401).json({ message: "Invalid email or password." });
    }

    if (user.passwordHash !== hashPassword(password)) {
      return res.status(401).json({ message: "Invalid email or password." });
    }

    return res.json({
      message: "Sign in successful.",
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        role: user.role,
      },
    });
  });

  router.get("/me", (req, res) => {
    const email = normalizeEmail(req.query.email);
    if (!email) {
      return res.status(400).json({ message: "Email is required." });
    }

    const user = users.get(email);
    if (!user) {
      return res.status(404).json({ message: "User not found." });
    }

    return res.json({
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        role: user.role,
      },
    });
  });

  return router;
}

module.exports = {
  USER_ROLES,
  validatePassword,
  normalizeEmail,
  hashPassword,
  createAuthRouter,
  users,
};
