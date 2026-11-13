export interface TrackingClaims {
  iss: "testerloop";
  aud: "sdk";
  sub: string;
  pkg: string;
  kind: "tester" | "owner_validation";
  tz: string;
  iat: number;
  exp: number;
}

function base64UrlEncode(data: Uint8Array): string {
  const bin = String.fromCharCode(...data);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function base64UrlDecode(str: string): Uint8Array {
  const padded = str.replace(/-/g, "+").replace(/_/g, "/") +
    "=".repeat((4 - (str.length % 4)) % 4);
  const bin = atob(padded);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) {
    out[i] = bin.charCodeAt(i);
  }
  return out;
}

export async function signTrackingJwt(
  claims: Omit<TrackingClaims, "iss" | "aud" | "iat" | "exp">,
  ttlSeconds = 30 * 24 * 3600,
): Promise<{ token: string; expiresAt: string }> {
  const rawJwk = Deno.env.get("TRACKING_JWT_PRIVATE_JWK");
  if (!rawJwk) {
    throw new Error("TRACKING_JWT_PRIVATE_JWK is not configured");
  }
  const jwk = JSON.parse(rawJwk) as JsonWebKey;
  const key = await crypto.subtle.importKey(
    "jwk",
    jwk,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );

  const now = Math.floor(Date.now() / 1000);
  const fullClaims: TrackingClaims = {
    iss: "testerloop",
    aud: "sdk",
    ...claims,
    iat: now,
    exp: now + ttlSeconds,
  };

  const encoder = new TextEncoder();
  const headerB64 = base64UrlEncode(
    encoder.encode(JSON.stringify({ alg: "ES256", typ: "JWT" })),
  );
  const payloadB64 = base64UrlEncode(
    encoder.encode(JSON.stringify(fullClaims)),
  );
  const signingInput = `${headerB64}.${payloadB64}`;

  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    encoder.encode(signingInput),
  );
  const sigB64 = base64UrlEncode(new Uint8Array(signature));
  return {
    token: `${signingInput}.${sigB64}`,
    expiresAt: new Date(fullClaims.exp * 1000).toISOString(),
  };
}

export async function verifyTrackingJwt(
  token: string,
): Promise<TrackingClaims | null> {
  const parts = token.split(".");
  if (parts.length !== 3) return null;

  const rawJwk = Deno.env.get("TRACKING_JWT_PUBLIC_JWK");
  if (!rawJwk) {
    throw new Error("TRACKING_JWT_PUBLIC_JWK is not configured");
  }
  const jwk = JSON.parse(rawJwk) as JsonWebKey;
  const key = await crypto.subtle.importKey(
    "jwk",
    jwk,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["verify"],
  );

  const [headerB64, payloadB64, sigB64] = parts;
  const encoder = new TextEncoder();
  const ok = await crypto.subtle.verify(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    base64UrlDecode(sigB64),
    encoder.encode(`${headerB64}.${payloadB64}`),
  );
  if (!ok) return null;

  const payload = JSON.parse(
    new TextDecoder().decode(base64UrlDecode(payloadB64)),
  ) as TrackingClaims;

  const now = Math.floor(Date.now() / 1000);
  if (
    payload.iss !== "testerloop" ||
    payload.aud !== "sdk" ||
    payload.exp <= now
  ) {
    return null;
  }
  return payload;
}
