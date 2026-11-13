import { corsHeaders, errorResponse, jsonResponse } from "../_shared/cors.ts";
import { createAdminClient } from "../_shared/supabase.ts";

interface PubSubPush {
  message?: {
    data?: string;
  };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return errorResponse("method_not_allowed", "Use POST", 405);
  }

  let body: PubSubPush;
  try {
    body = await req.json();
  } catch {
    return errorResponse("invalid_json", "Malformed Pub/Sub payload", 400);
  }

  const encoded = body.message?.data;
  if (!encoded) {
    return jsonResponse({ ok: true, ignored: true });
  }

  let decoded: {
    voidedPurchaseNotification?: { purchaseToken?: string };
    oneTimeProductNotification?: { purchaseToken?: string; notificationType?: number };
  };
  try {
    decoded = JSON.parse(atob(encoded));
  } catch {
    return errorResponse("invalid_base64", "Cannot decode RTDN message", 400);
  }

  const purchaseToken =
    decoded.voidedPurchaseNotification?.purchaseToken ??
    decoded.oneTimeProductNotification?.purchaseToken;

  if (!purchaseToken) {
    return jsonResponse({ ok: true, ignored: true });
  }

  if (decoded.voidedPurchaseNotification) {
    const admin = createAdminClient();
    const { data: purchase } = await admin
      .from("purchases")
      .update({ state: "refunded" })
      .eq("purchase_token", purchaseToken)
      .select("id")
      .maybeSingle();

    if (purchase) {
      await admin
        .from("featured_bookings")
        .update({ status: "cancelled" })
        .eq("purchase_id", purchase.id);
    }
  }

  return jsonResponse({ ok: true });
});
