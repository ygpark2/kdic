import { apiFetch } from '$lib/api';
import type { HomeResponse } from '$lib/types';

export async function load({ fetch }) {
  return apiFetch<HomeResponse>(fetch, '/api/home');
}
