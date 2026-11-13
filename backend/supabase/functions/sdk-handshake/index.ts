import { corsHeaders, errorResponse, jsonResponse } from "../_shared/cors.ts";
import { verifyTrackingJwt } from "../_shared/jwt.ts";
import { createAdminClient } from "../_shared/supabase.ts";

interface HandshakeBody {
  appKey: string;
  packageName: string;
  versionCode: number;
  signingCertSha256: string;
  installer?: string | null;
  debuggable: boolean;
  installId: string;
  sdk: { platform: string; version: string; wrapper?: string | null };
  token?: string | null;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return errorResponse("method_not_allowed", "Use POST", 405);
  }

  let body: HandshakeBody;
  try {
    body = await req.json();
  } catch {
    return errorResponse("invalid_json", "Malformed JSON body", 400);
  }

  if (!body.appKey || !body.packageName || !body.installId || !body.signingCertSha256) {
    return errorResponse("missing_fields", "Missing required handshake fields", 400);
  }

  const admin = createAdminClient();
  const { data: app, error: appErr } = await admin
    .from("apps")
    .select("id, package_name, signing_cert_sha256, sdk_debug_ok_at, sdk_verified_at")
    .eq("app_key", body.appKey)
    .maybeSingle();

  if (appErr || !app || app.package_name !== body.packageName) {
    return errorResponse("invalid_app_key", "appKey does not match packageName", 403);
  }

  const { data: liveCampaign } = await admin
    .from("campaigns")
    .select("id, status")
    .eq("app_id", app.id)
    .in("status", ["recruiting", "in_progress"])
    .maybeSingle();

  if (!body.token) {
    const enabled = Boolean(liveCampaign) || !app.sdk_verified_at;
    return jsonResponse({ status: enabled ? "not_enrolled" : "disabled", enabled, flushIntervalSec: 30 });
  }

  const claims = await verifyTrackingJwt(body.token);
  if (!claims || claims.pkg !== body.packageName) {
    return errorResponse("invalid_token", "Invalid or mismatched tracking token", 403);
  }

  const { data: enrollment } = await admin
    .from("enrollments")
    .select("id, status, kind, campaign_id")
    .eq("id", claims.sub)
    .maybeSingle();

  if (!enrollment || ["dropped", "rejected", "completed"].includes(enrollment.status)) {
    return jsonResponse({ status: "disabled", enabled: false, flushIntervalSec: 60 });
  }

  const isPlayInstaller = body.installer === "com.android.vending";

  if (enrollment.kind === "owner_validation") {
    if (isPlayInstaller && !body.debuggable) {
      // TOFU signing cert recording on first Play closed-track launch
      await admin
        .from("apps")
        .update({
          signing_cert_sha256: app.signing_cert_sha256 ?? body.signingCertSha256,
          sdk_verified_at: new Date().toISOString(),
        })
        .eq("id", app.id);
    } else {
      await admin
        .from("apps")
        .update({ sdk_debug_ok_at: new Date().toISOString() })
        .eq("id", app.id);
    }
  } else {
    if (!isPlayInstaller || body.debuggable) {
      return errorResponse("invalid_install_source", "Closed test build must come from Play Store", 403);
    }
    if (app.signing_cert_sha256 && app.signing_cert_sha256 !== body.signingCertSha256) {
      return errorResponse("cert_mismatch", "Signing certificate mismatch", 403);
    }
  }

  if (enrollment.status === "pending") {
    await admin
      .from("enrollments")
      .update({
        status: "active",
        first_handshake_at: new Date().toISOString(),
      })
      .eq("id", enrollment.id);
  }

  await admin.from("sdk_events").insert({
    app_id: app.id,
    enrollment_id: enrollment.id,
    install_id: body.installId,
    event_id: `hs_${body.installId}_${Date.now()}`,
    type: "handshake",
    payload: {
      versionCode: body.versionCode,
      installer: body.installer ?? null,
      debuggable: body.debuggable,
      sdk: body.sdk,
    },
  });

  return jsonResponse({ status: "tracking", enabled: true, flushIntervalSec: 30 });
});
