const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
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
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  try {
    const body = await req.json();
    const phone = normalizeIndianMobile(body?.phone);
    const password = typeof body?.password === "string" ? body.password : "";
    if (!phone || password.length < 8 || password.length > 256) {
      return json({ error: "मोबाइल नंबर या पासवर्ड गलत है, या ईमेल सत्यापन बाकी है।" }, 400);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const publicKey = Deno.env.get("SUPABASE_ANON_KEY") ?? Deno.env.get("SUPABASE_PUBLISHABLE_KEY");
    if (!supabaseUrl || !serviceKey || !publicKey) {
      return json({ error: "लॉगिन सेवा अभी उपलब्ध नहीं है।" }, 503);
    }

    const profileUrl = new URL("/rest/v1/profiles", supabaseUrl);
    profileUrl.searchParams.set("select", "id");
    profileUrl.searchParams.set("phone_normalized", `eq.${phone}`);
    profileUrl.searchParams.set("limit", "2");
    const profileResponse = await fetch(profileUrl, {
      headers: { apikey: serviceKey, Authorization: `Bearer ${serviceKey}` },
    });
    if (!profileResponse.ok) return json({ error: "लॉगिन सेवा अभी उपलब्ध नहीं है।" }, 503);
    const profiles = await profileResponse.json();
    let matchedUserId: string | null = null;
    let email: string | null = null;

    if (Array.isArray(profiles) && profiles.length === 1 && typeof profiles[0]?.id === "string") {
      matchedUserId = profiles[0].id;
    } else if (Array.isArray(profiles) && profiles.length === 0) {
      // New registrations store the mobile number in auth user metadata first.
      // Their public profile is created only after the email is confirmed and login succeeds.
      const usersUrl = new URL("/auth/v1/admin/users", supabaseUrl);
      usersUrl.searchParams.set("page", "1");
      usersUrl.searchParams.set("per_page", "1000");
      const usersResponse = await fetch(usersUrl, {
        headers: { apikey: serviceKey, Authorization: `Bearer ${serviceKey}` },
      });
      if (!usersResponse.ok) return json({ error: "लॉगिन सेवा अभी उपलब्ध नहीं है।" }, 503);
      const usersPayload = await usersResponse.json();
      const users = Array.isArray(usersPayload?.users) ? usersPayload.users : [];
      const matches = users.filter((user: any) =>
        normalizeIndianMobile(user?.user_metadata?.phone) === phone
      );
      if (matches.length === 1 && typeof matches[0]?.id === "string") {
        matchedUserId = matches[0].id;
        email = typeof matches[0]?.email === "string" ? matches[0].email : null;
      }
    }

    if (!matchedUserId) {
      return json({ error: "मोबाइल नंबर या पासवर्ड गलत है, या ईमेल सत्यापन बाकी है।" }, 401);
    }

    if (!email) {
      const userResponse = await fetch(
        new URL(`/auth/v1/admin/users/${encodeURIComponent(matchedUserId)}`, supabaseUrl),
        { headers: { apikey: serviceKey, Authorization: `Bearer ${serviceKey}` } },
      );
      if (!userResponse.ok) return json({ error: "मोबाइल नंबर या पासवर्ड गलत है, या ईमेल सत्यापन बाकी है।" }, 401);
      const userPayload = await userResponse.json();
      // The raw Auth Admin REST endpoint can return the user object directly;
// tolerate the SDK-style { user: ... } wrapper as well.
      const adminUser = userPayload?.user ?? userPayload;
      email = typeof adminUser?.email === "string" ? adminUser.email : null;
    }
    if (typeof email !== "string" || !email) {
      return json({ error: "मोबाइल नंबर या पासवर्ड गलत है, या ईमेल सत्यापन बाकी है।" }, 401);
    }

    // Let Supabase Auth verify the password and email-confirmation state.
    // The account email is never returned to the unauthenticated caller.
    const authResponse = await fetch(new URL("/auth/v1/token?grant_type=password", supabaseUrl), {
      method: "POST",
      headers: { apikey: publicKey, "Content-Type": "application/json" },
      body: JSON.stringify({ email, password }),
    });
    if (!authResponse.ok) {
      return json({ error: "मोबाइल नंबर या पासवर्ड गलत है, या ईमेल सत्यापन बाकी है।" }, 401);
    }
    const authPayload = await authResponse.json();
    if (typeof authPayload?.refresh_token !== "string" || !authPayload.refresh_token) {
      return json({ error: "लॉगिन पूरा नहीं हो पाया। दोबारा प्रयास करें।" }, 401);
    }
    return json({ refresh_token: authPayload.refresh_token });
  } catch {
    return json({ error: "लॉगिन पूरा नहीं हो पाया। मोबाइल नंबर और पासवर्ड जाँचें।" }, 400);
  }
});
