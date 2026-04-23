import { loadAdminJson } from '$lib/admin';
import type { AdminDashboardResponse } from '$lib/types';

export async function load({ fetch }) {
  return loadAdminJson<AdminDashboardResponse>(fetch, '/api/admin/dashboard', 'Failed to load admin dashboard.');
}
