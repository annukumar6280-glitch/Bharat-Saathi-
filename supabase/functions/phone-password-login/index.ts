const allowedOrigin = "https://annukumar6280-glitch.github.io";

function corsHeaders(req: Request) {
  const origin = req.headers.get("origin");
  return {
    ...(origin === allowedOrigin ? { "Access-Control-Allow-Origin": allowedOrigin } : {}),
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Vary": "Origin",
    "Cache-Control": "no-store",
  };
}

function json(req: Request, body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(req), "Content-Type": "application/json" },
  });
}

function normalizeIndianMobile(value: unknown): string | null {
  if (typeof value !== "string") return null;
  let digits = value.replace(/\D/g, "");
  if (digits.length === 12 && digits.startsWith("91")) digits = digits.slice(-10);
  if (digits.length === 11 && digits.startsWith("0")) digits = digits.slice(-10);
  return /^[6-9]\d{9}$/.test(digits) ? digits : null;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders(req) });
  if (req.method !== "POST") return json(req, { error: "Method not allowed" }, 405);

  try {
    const body = await req.json();
    const phone = normalizeIndianMobile(body?.phone);
    const password = typeof body?.password === "string" ? body.password : "";
    if (!phone || password.length < 8 || password.length > 256) {
      return json(req, { error: "मोबाइल नंबर या पासवर्ड गलत है, या ईमेल सत्यापन बाकी है।" }, 400);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const publicKey = Deno.env.get("SUPABASE_ANON_KEY") ?? Deno.env.get("SUPABASE_PUBLISHABLE_KEY");
    if (!supabaseUrl || !serviceKey || !publicKey) {
      return json(req, { error: "लॉगिन सेवा अभी उपलब्ध नहीं है।" }, 503);
    }

    const serviceHeaders = {
      apikey: serviceKey,
      Authorization: "Bearer " + serviceKey,
      "Content-Type": "application/json",
    };

    const sourceIp = req.headers.get("cf-connecting-ip")
      ?? req.headers.get("x-real-ip")
      ?? req.headers.get("x-forwarded-for")?.split(",")[0]?.trim()
      ?? "unknown";
    const rateResponse = await fetch(
      new URL("/rest/v1/rpc/consume_phone_login_rate_limit", supabaseUrl),
      {
        method: "POST",
        headers: serviceHeaders,
        body: JSON.stringify({ p_phone: phone, p_ip: sourceIp }),
      },
    );
    if (!rateResponse.ok) {
      return json(req, { error: "लॉगिन सेवा अभी उपलब्ध नहीं है।" }, 503);
    }
    if (await rateResponse.json() !== true) {
      return json(req, { error: "बहुत बार गलत लॉगिन प्रयास हुए हैं। सुरक्षा के लिए 15 मिनट बाद दोबारा प्रयास करें।" }, 429);
    }

    const lookupResponse = await fetch(
      new URL("/rest/v1/rpc/lookup_auth_user_for_phone_login", supabaseUrl),
      {
        method: "POST",
        headers: serviceHeaders,
        body: JSON.stringify({ p_phone: phone }),
      },
    );
    if (!lookupResponse.ok) {
      return json(req, { error: "लॉगिन सेवा अभी उपलब्ध नहीं है।" }, 503);
    }
    const matches = await lookupResponse.json();
    if (!Array.isArray(matches) || matches.length !== 1
      || typeof matches[0]?.user_email !== "string" || !matches[0].user_email) {
      return json(req, { error: "मोबाइल नंबर या पासवर्ड गलत है, या ईमेल सत्यापन बाकी है।" }, 401);
    }

    // Supabase Auth verifies the password and email-confirmation state.
    // The email is only passed server-to-server and is never returned to the app.
    const authResponse = await fetch(new URL("/auth/v1/token?grant_type=password", supabaseUrl), {
      method: "POST",
      headers: { apikey: publicKey, "Content-Type": "application/json" },
      body: JSON.stringify({ email: matches[0].user_email, password }),
    });
    if (!authResponse.ok) {
      return json(req, { error: "मोबाइल नंबर या पासवर्ड गलत है, या ईमेल सत्यापन बाकी है।" }, 401);
    }
    const authPayload = await authResponse.json();
    if (typeof authPayload?.refresh_token !== "string" || !authPayload.refresh_token) {
      return json(req, { error: "लॉगिन पूरा नहीं हो पाया। दोबारा प्रयास करें।" }, 401);
    }
    return json(req, { refresh_token: authPayload.refresh_token });
  } catch {
    return json(req, { error: "लॉगिन पूरा नहीं हो पाया। मोबाइल नंबर और पासवर्ड जाँचें।" }, 400);
  }
});
