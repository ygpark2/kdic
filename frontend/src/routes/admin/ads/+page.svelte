<script lang="ts">
  import { apiFormPost } from '$lib/api';
  import { formatTimestamp } from '$lib/format';
  import { base } from '$app/paths';
  import type { AdminAdRecord, AdminAdsResponse } from '$lib/types';

  interface Props {
    data: AdminAdsResponse;
  }

  let { data }: Props = $props();
  let items = $state<AdminAdRecord[]>([]);
  let message = $state('');
  let error = $state('');
  let hydrated = $state(false);

  $effect(() => {
    if (hydrated) return;
    items = data.items;
    hydrated = true;
  });

  async function deleteAd(id: number) {
    message = '';
    error = '';
    try {
      const response = await apiFormPost<{ message: string }>(
        `/api/admin/ads/${id}`,
        new URLSearchParams({ action: 'delete' })
      );
      items = items.filter((item) => item.id !== id);
      message = response.message;
    } catch (cause) {
      error = cause instanceof Error ? cause.message : 'Failed to delete ad.';
    }
  }
</script>

<div class="main-panel">
  <div class="main-panel-header">
    <p class="section-kicker">Ads</p>
    <h1 class="section-title">UI slots</h1>
    <p class="section-copy">Manage embed tags and custom sponsor cards from the frontend.</p>
  </div>

  <section class="composer-card">
    <div class="section-row">
      <div>
        <p class="section-kicker">Inventory</p>
        <h2 class="subsection-title">{items.length} ads</h2>
      </div>
      <a class="action-link" href={`${base}/admin/ads/new`}>Create ad</a>
    </div>

    {#if message}<p class="success-text">{message}</p>{/if}
    {#if error}<p class="error-text">{error}</p>{/if}

    {#if items.length}
      <div class="premium-list">
        {#each items as ad}
          <article class="premium-item">
            <div class="section-row">
              <div>
                <strong>{ad.title}</strong>
                <p class="rail-copy">
                  {ad.slot} · {ad.kind} · {ad.lifecycle} · order {ad.sortOrder}
                </p>
                <p class="rail-copy">
                  {ad.impressionCount} impressions · {ad.clickCount} clicks
                </p>
                {#if ad.lastClickedAt}
                  <p class="rail-copy">Last click {formatTimestamp(ad.lastClickedAt)}</p>
                {/if}
              </div>
              <div class="action-row">
                <a class="ghost-link" href={`${base}/admin/ads/id/${ad.id}`}>Edit</a>
                <button class="ghost-link" type="button" onclick={() => deleteAd(ad.id)}>Delete</button>
              </div>
            </div>
          </article>
        {/each}
      </div>
    {:else}
      <div class="empty-card"><p>No ads configured yet.</p></div>
    {/if}
  </section>
</div>
