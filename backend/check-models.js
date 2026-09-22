require('dotenv').config();
const axios = require('axios');

async function getAvailableModels() {
  try {
    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) {
      return console.log("❌ .env ফাইলে GEMINI_API_KEY পাওয়া যায়নি!");
    }

    console.log("⏳ গুগলের সার্ভার থেকে মডেলের লিস্ট আনা হচ্ছে...\n");

    const url = `https://generativelanguage.googleapis.com/v1beta/models?key=${apiKey}`;
    const response = await axios.get(url);

    console.log("✅ আপনার API Key-তে নিচের মডেলগুলো কাজ করবে:\n");
    
    response.data.models.forEach(model => {
      // শুধু সেই মডেলগুলো দেখাবে যেগুলো আমাদের টেক্সট জেনারেট করতে পারবে
      if (model.supportedGenerationMethods.includes('generateContent') && model.name.includes('gemini')) {
        console.log(`➡️ ${model.name.replace('models/', '')}`);
      }
    });

    console.log("\n💡 ওপরের লিস্ট থেকে যেকোনো একটি নাম server.js এ ব্যবহার করুন!");
  } catch (error) {
    console.error("❌ Error:", error.message);
  }
}

getAvailableModels();