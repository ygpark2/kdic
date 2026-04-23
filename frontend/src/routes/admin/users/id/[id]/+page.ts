import { loadAdminJson } from '$lib/admin';
import type { AdminUserDetailResponse } from '$lib/types';

export async function load({ fetch, params }) {
  return loadAdminJson<AdminUserDetailResponse>(
    fetch,
    `/api/admin/users/${params.id}`,
    'Failed to load user.'
  );
}
