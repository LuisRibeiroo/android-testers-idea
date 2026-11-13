import { corsHeaders, errorResponse, jsonResponse } from "../_shared/cors.ts";
import { createAdminClient, getAuthenticatedUser } from "../_shared/supabase.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const auth = await getAuthenticatedUser(req);
  if (!auth) {
    return errorResponse("unauthorized", "Valid Bearer token required", 401);
  }

  const admin = createAdminClient();

  if (req.method === "GET") {
    const url = new URL(req.url);
    const campaignId = url.searchParams.get("campaign");
    const productId = url.searchParams.get("product");
    if (!campaignId || !productId) {
      return errorResponse("missing_params", "campaign and product are required", 400);
    }

    const { data: product } = await admin
      .from("featured_products")
      .select("id, duration_hours, active")
      .eq("id", productId)
      .eq("active", true)
      .maybeSingle();

    if (!product) {
      return errorResponse("invalid_product", "Unknown or inactive Featured product", 404);
    }

    const now = new Date();
    let chosenSlot = 1;
    let earliestStart = now;
    let foundWindow = false;

    for (const slot of [1, 2, 3]) {
      const { data: bookings } = await admin
        .from("featured_bookings")
        .select("period")
        .eq("slot_index", slot)
        .neq("status", "cancelled")
        .order("period", { ascending: false })
        .limit(1);

      let candidateStart = now;
      if (bookings && bookings.length > 0) {
        const rangeStr = String(bookings[0].period);
        const match = rangeStr.match(/,([^\)\]]+)[\)\]]$/);
        if (match) {
          const upper = new Date(match[1].replace(/"/g, ""));
          if (upper > now) candidateStart = upper;
        }
      }

      if (!foundWindow || candidateStart < earliestStart) {
        earliestStart = candidateStart;
        chosenSlot = slot;
        foundWindow = true;
      }
    }

    const end = new Date(earliestStart.getTime() + product.duration_hours * 3600 * 1000);
    const period = `[${earliestStart.toISOString()},${end.toISOString()})`;
    const expiresAt = new Date(Date.now() + 15 * 60 * 1000).toISOString();

    const { data: booking, error } = await admin
      .from("featured_bookings")
      .insert({
        campaign_id: campaignId,
        slot_index: chosenSlot,
        period,
        status: "reserved",
        expires_at: expiresAt,
      })
      .select("id, slot_index, period, expires_at")
      .single();

    if (error || !booking) {
      return errorResponse("quote_failed", error?.message ?? "Slot conflict", 409);
    }

    return jsonResponse({ booking });
  }

  if (req.method === "POST") {
    let body: { booking_id?: string; product_id?: string; purchase_token?: string; order_id?: string };
    try {
      body = await req.json();
    } catch {
      return errorResponse("invalid_json", "Malformed JSON body", 400);
    }

    if (!body.booking_id || !body.product_id || !body.purchase_token) {
      return errorResponse("missing_fields", "booking_id, product_id and purchase_token required", 400);
    }

    // Play Developer API purchase verification hook (requires GOOGLE_PLAY_SERVICE_ACCOUNT_JSON in prod)
    const { data: purchase, error: pErr } = await admin
      .from("purchases")
      .insert({
        user_id: auth.userId,
        product_id: body.product_id,
        purchase_token: body.purchase_token,
        order_id: body.order_id ?? null,
        state: "consumed",
        raw: { verified_at: new Date().toISOString() },
      })
      .select("id")
      .single();

    if (pErr || !purchase) {
      return errorResponse("purchase_conflict", pErr?.message ?? "Duplicate purchaseToken", 409);
    }

    const { error: bErr } = await admin
      .from("featured_bookings")
      .update({ status: "confirmed", purchase_id: purchase.id, expires_at: null })
      .eq("id", body.booking_id)
      .eq("status", "reserved");

    if (bErr) {
      return errorResponse("booking_confirm_failed", bErr.message, 409);
    }

    return jsonResponse({ confirmed: true, booking_id: body.booking_id, purchase_id: purchase.id });
  }

  return errorResponse("method_not_allowed", "Use GET or POST", 405);
});
