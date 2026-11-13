import { corsHeaders, errorResponse, jsonResponse } from "../_shared/cors.ts";
import { createAdminClient, getAuthenticatedUser } from "../_shared/supabase.ts";

interface DeviceRegisterBody {
  android_id_hash: string;
  model?: string;
  sdk_int?: number;
  integrity_token?: string;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return errorResponse("method_not_allowed", "Use POST", 405);
  }

  const auth = await getAuthenticatedUser(req);
  if (!auth) {
    return errorResponse("unauthorized", "Valid Bearer token required", 401);
  }

  let body: DeviceRegisterBody;
  try {
    body = await req.json();
  } catch {
    return errorResponse("invalid_json", "Malformed JSON body", 400);
  }

  if (!body.android_id_hash) {
    return errorResponse("missing_android_id_hash", "android_id_hash is required", 400);
  }

  const admin = createAdminClient();
  const { data: existing } = await admin
    .from("devices")
    .select("id, user_id")
    .eq("android_id_hash", body.android_id_hash)
    .maybeSingle();

  if (existing && existing.user_id !== auth.userId) {
    return errorResponse("device_bound_other_account", "One account per device enforced", 409);
  }

  const integrityPassed = Boolean(body.integrity_token && body.integrity_token.length >= 8);
  const now = new Date().toISOString();

  const { data: device, error: devErr } = await admin
    .from("devices")
    .upsert(
      {
        user_id: auth.userId,
        android_id_hash: body.android_id_hash,
        model: body.model ?? null,
        sdk_int: body.sdk_int ?? null,
        integrity_ok_at: integrityPassed ? now : null,
        last_seen_at: now,
      },
      { onConflict: "android_id_hash" },
    )
    .select("id, integrity_ok_at")
    .single();

  if (devErr || !device) {
    return errorResponse("device_register_failed", devErr?.message ?? "Insert failed", 500);
  }

  let welcomeAwarded = false;
  if (integrityPassed) {
    const { data: prevWelcome } = await admin
      .from("points_ledger")
      .select("id")
      .eq("user_id", auth.userId)
      .eq("kind", "bonus_welcome")
      .maybeSingle();

    if (!prevWelcome) {
      await admin.from("points_ledger").insert({
        user_id: auth.userId,
        kind: "bonus_welcome",
        bucket: "available",
        amount: 10,
        ref_type: "device",
        ref_id: device.id,
      });
      welcomeAwarded = true;
    }
  }

  return jsonResponse({ device_id: device.id, welcome_awarded: welcomeAwarded });
});
