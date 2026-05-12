import { env } from "./env.ts";
import type { SupabaseClient } from "./supabase.ts";

type PermissionResult = {
  allowed: boolean;
  reason?: string;
};

export async function checkRateLimit(
  client: SupabaseClient,
  params: {
    userId: string;
    endpoint: string;
    action: string;
    limitCount?: number;
    windowSeconds?: number;
    metadata?: Record<string, unknown>;
  },
): Promise<PermissionResult> {
  const limitCount = params.limitCount ?? env.agentDailyRunLimit;
  const windowSeconds = params.windowSeconds ?? 60 * 60 * 24;
  const since = new Date(Date.now() - windowSeconds * 1000).toISOString();
  const rateLimitKey = `${params.userId}:${params.endpoint}:${params.action}`;

  const { count, error: countError } = await client
    .from("rate_limit_events")
    .select("id", { count: "exact", head: true })
    .eq("rate_limit_key", rateLimitKey)
    .eq("allowed", true)
    .gte("created_at", since);

  if (countError) {
    throw countError;
  }

  const allowed = (count ?? 0) < limitCount;
  const { error: insertError } = await client.from("rate_limit_events").insert({
    user_id: params.userId,
    endpoint: params.endpoint,
    rate_limit_key: rateLimitKey,
    action: params.action,
    allowed,
    cost: 1,
    limit_count: limitCount,
    window_seconds: windowSeconds,
    metadata: params.metadata ?? {},
  });

  if (insertError) {
    throw insertError;
  }

  return {
    allowed,
    reason: allowed ? undefined : "Daily agent run limit reached.",
  };
}

export async function requireConnectedAccount(
  client: SupabaseClient,
  params: {
    userId: string;
    provider: string;
    scopes?: string[];
  },
): Promise<PermissionResult> {
  const { data, error } = await client
    .from("connected_accounts")
    .select("id, scopes, status")
    .eq("user_id", params.userId)
    .eq("provider", params.provider)
    .eq("status", "connected")
    .limit(1)
    .maybeSingle();

  if (error) {
    throw error;
  }

  if (!data) {
    return { allowed: false, reason: `${params.provider} is not connected.` };
  }

  const scopes = new Set<string>((data.scopes ?? []) as string[]);
  const missing = (params.scopes ?? []).filter((scope) => !scopes.has(scope));
  if (missing.length > 0) {
    return {
      allowed: false,
      reason: `Missing required ${params.provider} scopes: ${missing.join(", ")}`,
    };
  }

  return { allowed: true };
}
