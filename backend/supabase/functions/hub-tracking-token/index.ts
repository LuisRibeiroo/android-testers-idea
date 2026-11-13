import { corsHeaders, errorResponse, jsonResponse } from "../_shared/cors.ts";
import { signTrackingJwt } from "../_shared/jwt.ts";
import { createAdminClient, getAuthenticatedUser } from "../_shared/supabase.ts";

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

  let body: { enrollment_id?: string };
  try {
    body = await req.json();
  } catch {
    return errorResponse("invalid_json", "Malformed JSON body", 400);
  }

  if (!body.enrollment_id) {
    return errorResponse("missing_enrollment_id", "enrollment_id is required", 400);
  }

  const admin = createAdminClient();
  const { data: enrollment } = await admin
    .from("enrollments")
    .select(`
      id,
      tester_id,
      kind,
      status,
      campaigns!inner (
        apps!inner (
          package_name
        )
      )
    `)
    .eq("id", body.enrollment_id)
    .maybeSingle();

  if (!enrollment || enrollment.tester_id !== auth.userId) {
    return errorResponse("forbidden", "Enrollment not found for user", 403);
  }

  if (["dropped", "rejected", "completed"].includes(enrollment.status)) {
    return errorResponse("enrollment_inactive", "Enrollment is no longer active", 409);
  }

  const { data: profile } = await admin
    .from("profiles")
    .select("timezone")
    .eq("id", auth.userId)
    .maybeSingle();

  const pkg = (enrollment.campaigns as { apps: { package_name: string } }).apps.package_name;

  const { token, expiresAt } = await signTrackingJwt({
    sub: enrollment.id,
    pkg,
    kind: enrollment.kind as "tester" | "owner_validation",
    tz: profile?.timezone ?? "America/Sao_Paulo",
  });

  return jsonResponse({ token, expires_at: expiresAt });
});
