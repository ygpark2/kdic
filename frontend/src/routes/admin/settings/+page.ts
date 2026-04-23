import { loadAdminJson } from '$lib/admin';
import type { AdminSettingsResponse } from '$lib/types';

export async function load({ fetch }) {
  return loadAdminJson<AdminSettingsResponse>(
    fetch,
    '/api/admin/settings',
    'Failed to load settings.'
  );
}
