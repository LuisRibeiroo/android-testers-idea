import { corsHeaders, errorResponse, jsonResponse } from "../_shared/cors.ts";
import { createAdminClient } from "../_shared/supabase.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "GET") {
    return errorResponse("method_not_allowed", "Use GET", 405);
  }

  const url = new URL(req.url);
  const appKey = url.searchParams.get("appKey");
  if (!appKey) {
    return errorResponse("missing_app_key", "Query param appKey is required", 400);
  }

  const admin = createAdminClient();
  const { data: app } = await admin
    .from("apps")
    .select("id, sdk_verified_at")
    .eq("app_key", appKey)
    .maybeSingle();

  if (!app) {
    return jsonResponse(
      { enabled: false, flushIntervalSec: 60 },
      200,
      { "Cache-Control": "public, max-age=300" },
    );
  }

  const { data: liveCampaign } = await admin
    .from("campaigns")
    .select("id")
    .eq("app_id", app.id)
    .in("status", ["recruiting", "in_progress"])
    .maybeSingle();

  const enabled = Boolean(liveCampaign) || !app.sdk_verified_at;
  return jsonResponse(
    { enabled, flushIntervalSec: 30 },
    200,
    { "Cache-Control": "public, max-age=300" },
  );
});
