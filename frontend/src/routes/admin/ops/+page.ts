import { loadAdminJson } from '$lib/admin';
import type { AdminOpsResponse } from '$lib/types';

export async function load({ fetch }) {
  return loadAdminJson<AdminOpsResponse>(fetch, '/api/admin/ops', 'Failed to load operations data.');
}
