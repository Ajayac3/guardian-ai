import { createClient } from 'npm:@supabase/supabase-js@2';
import { env } from './env.ts';

/// Service-role client (bypasses RLS) — for grant rows and lookups.
export const admin = createClient(env.supabaseUrl, env.serviceRoleKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});

/// Client acting as the calling user (RLS enforced).
export function userClient(authHeader: string) {
  return createClient(env.supabaseUrl, env.anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
}
