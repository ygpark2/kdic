import { loadAdminJson } from '$lib/admin';
import type { AdminSubmissionsResponse } from '$lib/types';

export async function load({ fetch }) {
  return loadAdminJson<AdminSubmissionsResponse>(
    fetch,
    '/api/admin/submissions',
    'Failed to load submissions.'
  );
}
