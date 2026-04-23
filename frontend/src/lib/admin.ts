import { base } from '$app/paths';
import { error, redirect } from '@sveltejs/kit';
import { baseUrl } from '$lib/api';

export async function loadAdminJson<T>(
  fetcher: typeof fetch,
  path: string,
  failureMessage: string
): Promise<T> {
  const response = await fetcher(`${baseUrl}${path}`, {
    credentials: 'include'
  });

  if (response.status === 401) {
    throw redirect(302, `${base}/login`);
  }

  if (response.status === 403) {
    throw error(403, 'Admin access required.');
  }

  if (!response.ok) {
    throw error(response.status, failureMessage);
  }

  return response.json() as Promise<T>;
}
