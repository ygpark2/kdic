import { baseUrl } from '$lib/api';
import { error, redirect } from '@sveltejs/kit';
import { base } from '$app/paths';
import type { NotificationsResponse } from '$lib/types';

export async function load({ fetch }) {
  const response = await fetch(`${baseUrl}/api/notifications`, {
    credentials: 'include'
  });

  if (response.status === 401) {
    throw redirect(302, `${base}/login`);
  }

  if (!response.ok) {
    throw error(response.status, 'Failed to load notifications.');
  }

  return (await response.json()) as NotificationsResponse;
}
