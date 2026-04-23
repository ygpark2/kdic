import { loadAdminJson } from '$lib/admin';
import type { AdminUsersResponse } from '$lib/types';

export async function load({ fetch }) {
  return loadAdminJson<AdminUsersResponse>(fetch, '/api/admin/users', 'Failed to load users.');
}
