import { apiFetch } from '$lib/api';
import type { ApiSession } from '$lib/types';

export async function load({ fetch }) {
  try {
    const session = await apiFetch<ApiSession>(fetch, '/api/session');
    return { session };
  } catch {
    return {
      session: {
        authenticated: false,
        user: null
      } satisfies ApiSession
    };
  }
}
