import { loadAdminJson } from '$lib/admin';
import type { AdminSettingDetailResponse } from '$lib/types';

export async function load({ fetch, params }) {
  return loadAdminJson<AdminSettingDetailResponse>(
    fetch,
    `/api/admin/settings/${params.id}`,
    'Failed to load setting.'
  );
}
