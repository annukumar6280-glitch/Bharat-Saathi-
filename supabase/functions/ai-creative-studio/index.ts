import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const geminiKey = Deno.env.get("GEMINI_API_KEY");
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return json({ error: "Sign in is required." }, 401);

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: authData, error: authError } = await userClient.auth.getUser();
  if (authError || !authData.user) return json({ error: "Your session is invalid. Please sign in again." }, 401);

  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return json({ error: "Invalid JSON request." }, 400); }
  if (body.generationType !== "image") {
    return json({ error: "Video generation needs a separately configured Google Veo / Vertex AI project and Cloud Storage bucket. No customer API key is required." }, 501);
  }
  const prompt = typeof body.prompt === "string" ? body.prompt.trim() : "";
  if (!prompt || prompt.length > 5000) return json({ error: "Please enter a prompt up to 5,000 characters." }, 400);
  const imageBase64 = typeof body.imageBase64 === "string" ? body.imageBase64 : null;
  const imageMimeType = typeof body.imageMimeType === "string" ? body.imageMimeType : "image/jpeg";
  if (imageBase64 && (!["image/jpeg", "image/png", "image/webp"].includes(imageMimeType) || imageBase64.length > 8_000_000)) {
    return json({ error: "Please upload a JPG, PNG or WebP image smaller than 6 MB." }, 400);
  }

  const admin = createClient(supabaseUrl, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: quota, error: quotaError } = await admin.rpc("consume_ai_generation_credit", { p_user_id: authData.user.id });
  if (quotaError) return json({ error: "AI usage limit service is temporarily unavailable." }, 503);
  if (!quota?.allowed) return json({ error: "Your 10 monthly free generations are used. A paid plan or credit pack will be available after billing is connected.", freeRemaining: 0, paidCredits: 0 }, 402);
  const source = String(quota.creditSource ?? "free");

  if (!geminiKey) {
    await admin.rpc("refund_ai_generation_credit", { p_user_id: authData.user.id, p_source: source });
    return json({ error: "AI service is not configured yet. Add GEMINI_API_KEY to Supabase Edge Function secrets." }, 503);
  }

  try {
    const parts: Array<Record<string, unknown>> = [{ text: prompt }];
    if (imageBase64) parts.push({ inlineData: { mimeType: imageMimeType, data: imageBase64 } });
    const response = await fetch("https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite-image:generateContent", {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-goog-api-key": geminiKey },
      body: JSON.stringify({
        contents: [{ role: "user", parts }],
        generationConfig: { responseModalities: ["TEXT", "IMAGE"], imageConfig: { aspectRatio: "4:5", imageSize: "1K" } },
      }),
    });
    const result = await response.json();
    if (!response.ok) throw new Error(result?.error?.message ?? "Gemini image generation failed.");
    const outputParts = result?.candidates?.[0]?.content?.parts ?? [];
    const image = outputParts.find((part: Record<string, unknown>) => part.inlineData)?.inlineData;
    if (!image?.data) throw new Error("Gemini did not return an image.");
    return json({ imageBase64: image.data, mimeType: image.mimeType ?? "image/png", freeRemaining: quota.freeRemaining ?? 0, paidCredits: quota.paidCredits ?? 0 }, 200);
  } catch (error) {
    await admin.rpc("refund_ai_generation_credit", { p_user_id: authData.user.id, p_source: source });
    return json({ error: error instanceof Error ? error.message : "Image generation failed." }, 502);
  }
});

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), { status, headers: { ...cors, "Content-Type": "application/json" } });
}
