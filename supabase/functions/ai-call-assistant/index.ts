import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const url = new URL(req.url);
  const action = url.searchParams.get("action") ?? "start-outbound";

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) return json({ error: "Backend is not configured" }, 503);

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  if (action === "status") {
    const expected = Deno.env.get("EXOTEL_STATUS_WEBHOOK_SECRET");
    const supplied = url.searchParams.get("token");
    if (!expected || !supplied || supplied !== expected) return json({ error: "Unauthorized webhook" }, 401);
    const form = await req.formData().catch(() => null);
    const payload: Record<string, string> = {};
    if (form) for (const [key, value] of form.entries()) payload[key] = String(value);
    if (!Object.keys(payload).length) {
      const body = await req.json().catch(() => ({}));
      Object.assign(payload, body);
    }
    const callSid = payload.CallSid ?? payload.call_sid ?? "";
    if (!callSid) return json({ error: "CallSid is required" }, 400);
    const rawStatus = (payload.Status ?? payload.CallStatus ?? payload.status ?? "").toLowerCase();
    const status = rawStatus === "completed" ? "completed"
      : rawStatus === "busy" || rawStatus === "no-answer" ? "missed"
      : rawStatus === "failed" ? "failed"
      : rawStatus === "in-progress" || rawStatus === "answered" ? "answered"
      : "received";
    const durationRaw = payload.ConversationDuration ?? payload.Duration ?? payload.duration;
    const duration = durationRaw && /^\d+$/.test(durationRaw) ? Number(durationRaw) : null;
    const { error } = await admin.from("ai_call_logs")
      .update({
        status,
        duration_seconds: duration,
        ended_at: ["completed", "missed", "failed"].includes(status) ? new Date().toISOString() : null,
      })
      .eq("provider_call_id", callSid);
    if (error) return json({ error: "Could not update call status" }, 500);
    return json({ ok: true });
  }

  const authorization = req.headers.get("Authorization") ?? "";
  const accessToken = authorization.replace(/^Bearer\s+/i, "");
  if (!accessToken) return json({ error: "Sign in is required" }, 401);
  const userClient = createClient(supabaseUrl, Deno.env.get("SUPABASE_ANON_KEY") ?? "", {
    global: { headers: { Authorization: `Bearer ${accessToken}` } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: authData, error: authError } = await userClient.auth.getUser(accessToken);
  const user = authData.user;
  if (authError || !user) return json({ error: "Invalid session" }, 401);

  if (action !== "start-outbound") return json({ error: "Unknown action" }, 400);
  const body = await req.json().catch(() => ({}));
  const to = String(body.to ?? "").trim();
  if (!/^\+91[6-9]\d{9}$/.test(to)) return json({ error: "Enter a valid Indian mobile number in +91 format" }, 400);

  const { data: settings, error: settingsError } = await admin.from("ai_call_assistant_settings")
    .select("phone_number,assistant_instructions,disclosure_accepted_at,enabled,phone_verification_status")
    .eq("user_id", user.id)
    .maybeSingle();
  if (settingsError || !settings?.phone_number) return json({ error: "Save your AI Calling Assistant settings first" }, 400);
  if (!settings.disclosure_accepted_at) return json({ error: "AI disclosure consent is required before calling" }, 403);
  if (settings.phone_verification_status !== "verified") {
    return json({ error: "Carrier number verification is not configured for this account yet" }, 409);
  }

  const apiKey = Deno.env.get("EXOTEL_API_KEY");
  const apiToken = Deno.env.get("EXOTEL_API_TOKEN");
  const accountSid = Deno.env.get("EXOTEL_ACCOUNT_SID");
  const callerId = Deno.env.get("EXOTEL_CALLER_ID");
  const streamUrl = Deno.env.get("EXOTEL_AI_STREAM_URL");
  const webhookSecret = Deno.env.get("EXOTEL_STATUS_WEBHOOK_SECRET");
  if (!apiKey || !apiToken || !accountSid || !callerId || !streamUrl || !webhookSecret) {
    return json({ error: "Exotel voice service is not provisioned yet" }, 503);
  }
  if (!streamUrl.startsWith("wss://")) return json({ error: "AI stream URL must use secure WSS" }, 503);

  const callback = `${supabaseUrl}/functions/v1/ai-call-assistant?action=status&token=${encodeURIComponent(webhookSecret)}`;
  const form = new URLSearchParams();
  form.set("From", to);
  form.set("CallerId", callerId);
  form.set("StreamUrl", streamUrl);
  form.set("StreamType", "bidirectional");
  form.set("Record", "false");
  form.set("StatusCallback", callback);
  form.append("StatusCallbackEvents[]", "answered");
  form.append("StatusCallbackEvents[]", "terminal");
  form.set("CustomField", user.id);

  const exotelResponse = await fetch(
    `https://api.in.exotel.com/v1/Accounts/${encodeURIComponent(accountSid)}/Calls/connect`,
    {
      method: "POST",
      headers: {
        Authorization: `Basic ${btoa(`${apiKey}:${apiToken}`)}`,
        "Content-Type": "application/x-www-form-urlencoded",
        Accept: "application/json",
      },
      body: form,
    },
  );
  const providerBody = await exotelResponse.json().catch(() => ({}));
  if (!exotelResponse.ok) {
    return json({ error: "Exotel could not start the call", provider_status: exotelResponse.status }, 502);
  }
  const call = providerBody?.Call ?? providerBody?.call ?? {};
  const callSid = String(call.Sid ?? call.sid ?? "");
  if (!callSid) return json({ error: "Exotel response did not include a call ID" }, 502);

  const { error: logError } = await admin.from("ai_call_logs").insert({
    user_id: user.id,
    provider_call_id: callSid,
    direction: "outgoing",
    caller_number: to,
    status: "received",
    started_at: new Date().toISOString(),
  });
  if (logError) return json({ error: "Call started but its log could not be saved" }, 500);
  return json({ ok: true, call_id: callSid, status: call.Status ?? call.status ?? "queued" });
});
