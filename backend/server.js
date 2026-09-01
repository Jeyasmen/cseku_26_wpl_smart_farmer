const express = require("express");
const cors = require("cors");
const { createAuthRouter } = require("./src/auth");

const app = express();

app.use(cors());
app.use(express.json());

app.get("/", (req, res) => {
  res.send("Smart Farmer Backend is running!");
});

app.get("/api/health", (req, res) => {
  res.json({ ok: true, service: "smart-farmer-backend" });
});

app.use("/api/auth", createAuthRouter());

const PORT = 5000;

app.listen(PORT, () => {
  console.log(`Server running on http://localhost:${PORT}`);
});