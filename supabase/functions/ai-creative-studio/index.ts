import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const falKey = Deno.env.get("FAL_KEY");
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return json({ error: "Sign in is required." }, 401);

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

  const action = typeof body.action === "string" ? body.action : "generate";
  const generationType = body.generationType === "image" || body.generationType === "video"
    ? body.generationType
    : null;
  const admin = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  if (action === "video_status") {
    return await videoStatus(body, authData.user.id, admin, falKey);
  }
  if (action !== "generate" || !generationType) {
    return json({ error: "Invalid AI generation request." }, 400);
  }

  const prompt = typeof body.prompt === "string" ? body.prompt.trim() : "";
  if (!prompt || prompt.length > 5000) {
    return json({ error: "Please enter a prompt up to 5,000 characters." }, 400);
  }

  const imageBase64 = typeof body.imageBase64 === "string" ? body.imageBase64 : null;
  const imageMimeType = typeof body.imageMimeType === "string" ? body.imageMimeType : "image/jpeg";
  if (imageBase64 && (!["image/jpeg", "image/png", "image/webp"].includes(imageMimeType) || imageBase64.length > 8_000_000)) {
    return json({ error: "Please upload a JPG, PNG or WebP image smaller than 6 MB." }, 400);
  }

  if (!falKey) {
    return json({ error: "AI image service is not configured. Please add FAL_KEY in Supabase Edge Function Secrets. No coins were charged." }, 503);
  }

  const { data: quota, error: quotaError } = await admin.rpc("consume_ai_coin_credit", {
    p_user_id: authData.user.id,
    p_generation_type: generationType,
  });
  if (quotaError) return json({ error: "AI coin wallet service is temporarily unavailable." }, 503);
  if (!quota?.allowed) {
    return json({
      error: "आपके इस महीने के मुफ्त फोटो पूरे हो गए हैं या वॉलेट में पर्याप्त कॉइन नहीं हैं।",
      freeRemaining: quota?.freeRemaining ?? 0,
      coinBalance: quota?.coinBalance ?? 0,
      coinCost: quota?.coinCost ?? 5,
      needsCoins: true,
    }, 402);
  }

  const source = String(quota.creditSource ?? "free");
  if (generationType === "video") {
    const model = imageBase64
      ? "fal-ai/kling-video/v2.5-turbo/pro/image-to-video"
      : "fal-ai/kling-video/v2.5-turbo/pro/text-to-video";
    try {
      const input: Record<string, unknown> = {
        prompt,
        duration: "5",
        aspect_ratio: "9:16",
        enable_safety_checker: true,
        negative_prompt: "blur, distort, flicker, low quality, watermark, unreadable text",
      };
      if (imageBase64) input.image_url = `data:${imageMimeType};base64,${imageBase64}`;
      const submit = await fetch(`https://queue.fal.run/${model}`, {
        method: "POST",
        headers: { "Authorization": `Key ${falKey}`, "Content-Type": "application/json" },
        body: JSON.stringify(input),
      });
      const queued = await submit.json().catch(() => ({}));
      if (!submit.ok || typeof queued?.request_id !== "string") {
        throw new Error(typeof queued?.detail === "string" ? queued.detail : `fal.ai video queue failed (HTTP ${submit.status}).`);
      }
      const { error: jobError } = await admin.from("ai_video_jobs").insert({
        request_id: queued.request_id,
        user_id: authData.user.id,
        credit_source: source,
        status: "IN_QUEUE",
      });
      if (jobError) {
        try {
          await fetch(`https://queue.fal.run/${model}/requests/${queued.request_id}/cancel`, {
            method: "PUT", headers: { "Authorization": `Key ${falKey}` },
          });
        } catch (_) {}
        throw new Error("वीडियो जॉब सेव नहीं हो पाई। अनुरोध रद्द करने की कोशिश की गई है।");
      }
      return json({
        requestId: queued.request_id, model, status: "IN_QUEUE",
        coinCost: quota.coinCost ?? 50, coinBalance: quota.coinBalance ?? 0,
        provider: "fal.ai",
      }, 202);
    } catch (error) {
      await admin.rpc("refund_ai_coin_credit", {
        p_user_id: authData.user.id, p_source: source, p_generation_type: "video",
      });
      const message = error instanceof Error ? error.message : "Video generation could not be queued.";
      return json({ error: `AI वीडियो शुरू नहीं हो पाया: ${message}`, refund: true }, 502);
    }
  }
  try {
    const endpoint = imageBase64
      ? "https://fal.run/fal-ai/flux-2/flash/edit"
      : "https://fal.run/fal-ai/flux/schnell";

    const input: Record<string, unknown> = imageBase64
      ? {
          prompt,
          image_urls: [`data:${imageMimeType};base64,${imageBase64}`],
          image_size: { width: 1024, height: 1280 },
          num_images: 1,
          output_format: "png",
          enable_safety_checker: true,
        }
      : {
          prompt,
          image_size: { width: 1024, height: 1280 },
          num_inference_steps: 4,
          num_images: 1,
          output_format: "png",
          enable_safety_checker: true,
        };

    const response = await fetch(endpoint, {
      method: "POST",
      headers: {
        "Authorization": `Key ${falKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(input),
    });

    const result = await response.json().catch(() => ({}));
    if (!response.ok) {
      const detail = typeof result?.detail === "string"
        ? result.detail
        : typeof result?.error === "string"
          ? result.error
          : `fal.ai request failed (HTTP ${response.status}).`;
      throw new Error(detail);
    }

    const imageUrl = result?.images?.[0]?.url;
    if (typeof imageUrl !== "string" || !imageUrl) {
      throw new Error("fal.ai ने इमेज URL नहीं लौटाया। कृपया दोबारा कोशिश करें।");
    }

    const imageResponse = await fetch(imageUrl);
    if (!imageResponse.ok) throw new Error("बनी हुई इमेज डाउनलोड नहीं हो पाई।");
    const imageBuffer = await imageResponse.arrayBuffer();
    if (imageBuffer.byteLength === 0 || imageBuffer.byteLength > 12_000_000) {
      throw new Error("AI इमेज का आकार मान्य सीमा से बाहर है।");
    }

    return json({
      imageBase64: encodeBase64(new Uint8Array(imageBuffer)),
      mimeType: imageResponse.headers.get("content-type")?.split(";")[0] ?? "image/png",
      freeRemaining: quota.freeRemaining ?? 0,
      coinBalance: quota.coinBalance ?? 0,
      coinCost: quota.coinCost ?? 0,
      creditSource: source,
      provider: "fal.ai",
      model: imageBase64 ? "fal-ai/flux-2/flash/edit" : "fal-ai/flux/schnell",
    }, 200);
  } catch (error) {
    await admin.rpc("refund_ai_coin_credit", {
      p_user_id: authData.user.id,
      p_source: source,
      p_generation_type: generationType,
    });
    const message = error instanceof Error ? error.message : "Image generation failed.";
    return json({
      error: `AI फोटो नहीं बन पाई: ${message}`,
      refund: true,
    }, 502);
  }
});


async function videoStatus(
  body: Record<string, unknown>,
  userId: string,
  admin: ReturnType<typeof createClient>,
  falKey: string | undefined,
): Promise<Response> {
  if (!falKey) return json({ error: "FAL_KEY is not configured." }, 503);
  const requestId = typeof body.requestId === "string" ? body.requestId : "";
  const model = typeof body.model === "string" ? body.model : "";
  const allowedModels = new Set([
    "fal-ai/kling-video/v2.5-turbo/pro/text-to-video",
    "fal-ai/kling-video/v2.5-turbo/pro/image-to-video",
  ]);
  if (!/^[0-9a-f-]{20,60}$/i.test(requestId) || !allowedModels.has(model)) {
    return json({ error: "Invalid video request reference." }, 400);
  }
  const { data: job, error: jobError } = await admin.from("ai_video_jobs")
    .select("request_id,user_id,credit_source,status,refunded_at")
    .eq("request_id", requestId).eq("user_id", userId).maybeSingle();
  if (jobError || !job) return json({ error: "Video request not found." }, 404);
  try {
    const statusResponse = await fetch(
      `https://queue.fal.run/${model}/requests/${requestId}/status`,
      { headers: { "Authorization": `Key ${falKey}` } },
    );
    const statusData = await statusResponse.json().catch(() => ({}));
    if (!statusResponse.ok) throw new Error(`Video status check failed (HTTP ${statusResponse.status}).`);
    const status = String(statusData?.status ?? "IN_PROGRESS");
    if (status === "COMPLETED") {
      const resultResponse = await fetch(
        `https://queue.fal.run/${model}/requests/${requestId}`,
        { headers: { "Authorization": `Key ${falKey}` } },
      );
      const result = await resultResponse.json().catch(() => ({}));
      if (!resultResponse.ok || typeof result?.video?.url !== "string") {
        throw new Error("Video result is not available yet.");
      }
      await admin.from("ai_video_jobs").update({ status: "COMPLETED" })
        .eq("request_id", requestId).eq("user_id", userId);
      return json({ status: "COMPLETED", videoUrl: result.video.url, contentType: result.video.content_type ?? "video/mp4" });
    }
    if (status === "FAILED" || status === "CANCELLED") {
      const { data: claimed } = await admin.from("ai_video_jobs")
        .update({ status: "FAILED", refunded_at: new Date().toISOString() })
        .eq("request_id", requestId).eq("user_id", userId).is("refunded_at", null)
        .select("request_id").maybeSingle();
      if (claimed) {
        await admin.rpc("refund_ai_coin_credit", {
          p_user_id: userId, p_source: job.credit_source, p_generation_type: "video",
        });
      }
      return json({ status: "FAILED", error: "वीडियो नहीं बन पाया। आपके कॉइन वापस कर दिए गए हैं।" });
    }
    const normalized = status === "IN_QUEUE" ? "IN_QUEUE" : "IN_PROGRESS";
    await admin.from("ai_video_jobs").update({ status: normalized })
      .eq("request_id", requestId).eq("user_id", userId);
    return json({ status: normalized });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Could not check video status.";
    return json({ error: message }, 502);
  }
}

function encodeBase64(bytes: Uint8Array): string {
  let binary = "";
  const chunkSize = 0x8000;
  for (let i = 0; i < bytes.length; i += chunkSize) {
    binary += String.fromCharCode(...bytes.subarray(i, i + chunkSize));
  }
  return btoa(binary);
}

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}