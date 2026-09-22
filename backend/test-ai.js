require('dotenv').config();
const { GoogleGenerativeAI } = require('@google/generative-ai');

async function testGemini() {
  try {
    console.log("🤖 AI টেস্টিং শুরু হচ্ছে (gemini-1.5-pro)...");
    
    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) {
      console.log("❌ Error: .env ফাইলে GEMINI_API_KEY পাওয়া যায়নি!");
      return;
    }

    const genAI = new GoogleGenerativeAI(apiKey);
    const model = genAI.getGenerativeModel({ model: "gemini-3.6-flash" });

    const cropType = "Tomato (টমেটো)"; // আপনি চাইলে এখানে ফসলের নাম পরিবর্তন করে টেস্ট করতে পারেন
    
    const prompt = `
      You are an elite, highly experienced Agronomist in Bangladesh. 
      The farmer is cultivating "${cropType}". 
      Generate a professional timeline of 3 crucial farming activities.
      Return strictly ONLY a valid JSON array. Do not include markdown formatting (like \`\`\`json) or any extra explanations.
      
      Format of each object in the array:
      {
        "title": "Professional task name combining Bengali and English terms",
        "activityType": "Must be strictly one of these exact strings: Watering, Fertilizing, Maintenance, Pesticide, Harvesting, Monitoring",
        "daysAfterSowing": Exact integer representing days from planting date,
        "isUrgent": boolean
      }
    `;

    console.log(`📡 ${cropType} এর জন্য রিকোয়েস্ট পাঠানো হচ্ছে...`);
    const result = await model.generateContent(prompt);
    const aiResponse = result.response.text().trim();
    
    console.log("\n✅ AI এর সফল উত্তর (JSON):\n");
    console.log(aiResponse);

  } catch (error) {
    console.error("\n❌ AI Error:", error.message);
  }
}

testGemini();