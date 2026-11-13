import { corsHeaders, errorResponse, jsonResponse } from "../_shared/cors.ts";
import { createAdminClient, getAuthenticatedUser } from "../_shared/supabase.ts";

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

  const auth = await getAuthenticatedUser(req);
  if (!auth) {
    return errorResponse("unauthorized", "Valid Bearer token required", 401);
  }

  let body: { packages?: string[] };
  try {
    body = await req.json();
  } catch {
    return errorResponse("invalid_json", "Malformed JSON body", 400);
  }

  const packages = Array.isArray(body.packages) ? body.packages : [];
  const admin = createAdminClient();

  const { data: profile } = await admin
    .from("profiles")
    .select("timezone")
    .eq("id", auth.userId)
    .maybeSingle();

  const day = getLocalDay(profile?.timezone ?? "America/Sao_Paulo");

  const { data: enrollments } = await admin
    .from("enrollments")
    .select(`
      id,
      campaigns!inner (
        apps!inner (
          package_name
        )
      )
    `)
    .eq("tester_id", auth.userId)
    .in("status", ["active", "at_risk"]);

  let updated = 0;
  for (const enr of enrollments ?? []) {
    const pkg = (enr.campaigns as { apps: { package_name: string } }).apps.package_name;
    if (!packages.includes(pkg)) continue;

    const { data: existing } = await admin
      .from("daily_activity")
      .select("foreground_seconds, sessions, sources")
      .eq("enrollment_id", enr.id)
      .eq("day", day)
      .maybeSingle();

    const sources = Array.from(new Set([...(existing?.sources ?? []), "hub_presence"]));
    await admin.from("daily_activity").upsert({
      enrollment_id: enr.id,
      day,
      present: true,
      foreground_seconds: existing?.foreground_seconds ?? 0,
      sessions: existing?.sessions ?? 0,
      sources,
    });
    updated += 1;
  }

  return jsonResponse({ day, recorded: updated });
});
