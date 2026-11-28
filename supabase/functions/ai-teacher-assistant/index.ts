import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "Method not allowed." }, 405);

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return json({ error: "Sign in is required." }, 401);

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: authData, error: authError } = await userClient.auth.getUser();
  if (authError || !authData.user) {
    return json({ error: "Your session is invalid. Please sign in again." }, 401);
  }

  let body: Record<string, unknown>;
  try { body = await req.json(); } catch {
    return json({ error: "Invalid JSON request." }, 400);
  }

  const question = typeof body.question === "string" ? body.question.trim() : "";
  const course = typeof body.course === "string" ? body.course.slice(0, 100) : "General learning";
  const part = typeof body.part === "string" ? body.part.slice(0, 120) : "";
  const lesson = typeof body.lesson === "string" ? body.lesson.slice(0, 120) : "";
  const language = body.language === "English" ? "English" : "Hindi";
  if (!question || question.length > 2000) {
    return json({ error: "कृपया 1 से 2,000 अक्षरों के बीच अपना सवाल लिखें।" }, 400);
  }

  const system = [
    "You are Bharat Saathi AI Teacher, a patient and practical tutor.",
    "Teach step by step in simple language. Do not merely give a one-line answer.",
    "When asked to teach a complete lesson, produce a self-contained mini-chapter with learning objectives, prerequisites, definitions, numbered explanations, worked examples, practical activities, common mistakes, recap, five review questions with answers, and homework.",
    "Adapt depth to the selected syllabus level: Level 1 is beginner, Levels 2-3 build competence, Levels 4-5 are practical/intermediate, and Level 6 is advanced. Never skip foundational steps.",
    "Use Indian context, INR examples where useful, and explain English technical terms in Hindi when answering in Hindi.",
    "Use short examples, explain unfamiliar terms, and ask one focused check-for-understanding question when useful.",
    "For mathematics, show the calculation steps. For English, provide a natural example and a gentle correction.",
    "For computer and digital skills, explain safe, beginner-friendly steps.",
    "For business topics, distinguish general education from legal, tax, or financial advice and avoid pretending to be a licensed professional.",
    "Stay within the selected course and lesson unless the learner asks otherwise.",
    "Answer in " + language + ".",
  ].join(" ");

  const prompt = "Course: " + course + "\nPart: " + part + "\nLesson: " + lesson + "\nTeach only the selected part and lesson. If the learner asks about something else, gently connect the answer back to the selected lesson.\nLearner question: " + question;

  const openAiKey = Deno.env.get("OPENAI_API_KEY");
  const geminiKey = Deno.env.get("GEMINI_API_KEY");
  const failures: string[] = [];

  if (openAiKey) {
    try {
      const response = await fetch("https://api.openai.com/v1/chat/completions", {
        method: "POST",
        headers: { "Authorization": "Bearer " + openAiKey, "Content-Type": "application/json" },
        body: JSON.stringify({
          model: "gpt-4o-mini",
          messages: [{ role: "system", content: system }, { role: "user", content: prompt }],
          max_tokens: 1800,
          temperature: 0.35,
        }),
      });
      const result = await response.json().catch(() => ({}));
      if (!response.ok) throw new Error("OpenAI HTTP " + response.status);
      const answer = result?.choices?.[0]?.message?.content;
      if (typeof answer !== "string" || !answer.trim()) throw new Error("OpenAI returned an empty answer.");
      return json({ answer: answer.trim(), provider: "OpenAI", model: "gpt-4o-mini" });
    } catch (error) {
      failures.push(error instanceof Error ? error.message : "OpenAI request failed");
    }
  }

  if (geminiKey) {
    try {
      const response = await fetch(
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=" + encodeURIComponent(geminiKey),
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            systemInstruction: { parts: [{ text: system }] },
            contents: [{ role: "user", parts: [{ text: prompt }] }],
            generationConfig: { maxOutputTokens: 1800, temperature: 0.35 },
          }),
        },
      );
      const result = await response.json().catch(() => ({}));
      if (!response.ok) throw new Error("Gemini HTTP " + response.status);
      const answer = result?.candidates?.[0]?.content?.parts?.map((part: { text?: string }) => part.text ?? "").join("");
      if (typeof answer !== "string" || !answer.trim()) throw new Error("Gemini returned an empty answer.");
      return json({ answer: answer.trim(), provider: "Gemini", model: "gemini-2.5-flash" });
    } catch (error) {
      failures.push(error instanceof Error ? error.message : "Gemini request failed");
    }
  }

  const detail = failures.length ? failures.join("; ") : "OPENAI_API_KEY या GEMINI_API_KEY Supabase Edge Function Secrets में सेट नहीं है।";
  return json({ error: "AI Teacher सेवा उपलब्ध नहीं है। " + detail }, 503);
});

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}
