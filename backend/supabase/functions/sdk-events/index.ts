import { corsHeaders, errorResponse, jsonResponse } from "../_shared/cors.ts";
import { verifyTrackingJwt } from "../_shared/jwt.ts";
import { createAdminClient } from "../_shared/supabase.ts";

interface EventItem {
  type: "ping" | "session";
  id: string;
  clientTs?: number;
  startTs?: number;
  foregroundMs?: number;
}

interface EventsBody {
  appKey: string;
  packageName: string;
  installId: string;
  token: string;
  events: EventItem[];
}

function getLocalDay(tz: string): string {
  try {
    return new Intl.DateTimeFormat("en-CA", {
      timeZone: tz,
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
    }).format(new Date());
  } catch {
    return new Date().toISOString().slice(0, 10);
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return errorResponse("method_not_allowed", "Use POST", 405);
  }

  let body: EventsBody;
  try {
    body = await req.json();
  } catch {
    return errorResponse("invalid_json", "Malformed JSON body", 400);
  }

  if (!body.appKey || !body.packageName || !body.token || !Array.isArray(body.events)) {
    return errorResponse("missing_fields", "Missing required fields", 400);
  }

  const claims = await verifyTrackingJwt(body.token);
  if (!claims || claims.pkg !== body.packageName) {
    return errorResponse("invalid_token", "Invalid or expired tracking token", 403);
  }

  const admin = createAdminClient();
  const { data: app } = await admin
    .from("apps")
    .select("id, package_name")
    .eq("app_key", body.appKey)
    .maybeSingle();

  if (!app || app.package_name !== body.packageName) {
    return errorResponse("invalid_app_key", "Unknown appKey", 403);
  }

  const { data: enrollment } = await admin
    .from("enrollments")
    .select("id, status, campaign_id")
    .eq("id", claims.sub)
    .maybeSingle();

  if (!enrollment || !["active", "at_risk"].includes(enrollment.status)) {
    return jsonResponse({ accepted: [], enabled: false });
  }

  const accepted: string[] = [];
  let addedFgSeconds = 0;
  let addedSessions = 0;

  for (const ev of body.events.slice(0, 100)) {
    if (!ev.id || (ev.type !== "ping" && ev.type !== "session")) continue;

    const { data: existing } = await admin
      .from("sdk_events")
      .select("id")
      .eq("app_id", app.id)
      .eq("install_id", body.installId)
      .eq("event_id", ev.id)
      .maybeSingle();

    if (existing) {
      accepted.push(ev.id);
      continue;
    }

    await admin.from("sdk_events").insert({
      app_id: app.id,
      enrollment_id: enrollment.id,
      install_id: body.installId,
      event_id: ev.id,
      type: ev.type,
      payload: ev,
    });

    accepted.push(ev.id);
    if (ev.type === "session" && typeof ev.foregroundMs === "number" && ev.foregroundMs > 0) {
      const cappedSec = Math.min(Math.floor(ev.foregroundMs / 1000), 4 * 3600);
      addedFgSeconds += cappedSec;
      addedSessions += 1;
    }
  }

  const day = getLocalDay(claims.tz);
  const { data: currentDay } = await admin
    .from("daily_activity")
    .select("foreground_seconds, sessions, sources")
    .eq("enrollment_id", enrollment.id)
    .eq("day", day)
    .maybeSingle();

  const mergedSources = Array.from(new Set([...(currentDay?.sources ?? []), "sdk"]));

  await admin.from("daily_activity").upsert({
    enrollment_id: enrollment.id,
    day,
    present: true,
    foreground_seconds: (currentDay?.foreground_seconds ?? 0) + addedFgSeconds,
    sessions: (currentDay?.sessions ?? 0) + addedSessions,
    sources: mergedSources,
  });

  return jsonResponse({ accepted, enabled: true });
});
