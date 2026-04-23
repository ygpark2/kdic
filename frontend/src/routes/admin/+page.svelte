<script lang="ts">
  import { base } from '$app/paths';
  import type { AdminDashboardResponse } from '$lib/types';

  interface Props {
    data: AdminDashboardResponse;
  }

  let { data }: Props = $props();
  const statCards = $derived([
    ['Words', data.stats.totalWords, 'Dictionary entries ready to publish.'],
    ['Users', data.stats.totalUsers, 'Accounts that can use the product.'],
    ['Premium', data.stats.premiumUsers, 'Accounts with premium access enabled.'],
    ['Pending', data.stats.pendingSubmissions, 'Submitted words waiting for review.'],
    ['Ads', data.stats.totalAds, 'Configured ad creatives across slots.'],
    ['Live Ads', data.stats.liveAds, 'Ads currently eligible to serve.'],
    ['Impressions', data.stats.totalAdImpressions, 'Tracked card loads from admin-managed slots.'],
    ['Clicks', data.stats.totalAdClicks, 'Tracked outbound ad clicks.']
  ]);
</script>

<div class="main-panel">
  <div class="main-panel-header">
    <p class="section-kicker">Overview</p>
    <h1 class="section-title">Admin dashboard</h1>
    <p class="section-copy">All management areas now run through the split frontend.</p>
  </div>

  <section class="feed-section">
    <div class="admin-stats-grid">
      {#each statCards as [label, value, copy]}
        <article class="rail-card rail-stack">
          <p class="rail-label">{label}</p>
          <strong class="admin-stat-value">{value}</strong>
          <p class="rail-copy">{copy}</p>
        </article>
      {/each}
    </div>
  </section>

  <section class="composer-card">
    <div class="section-row">
      <div>
        <p class="section-kicker">Recent words</p>
        <h2 class="subsection-title">Latest dictionary entries</h2>
      </div>
      <a class="action-link" href={`${base}/admin/words/new`}>Create word</a>
    </div>

    {#if data.recentWords.length}
      <div class="premium-list">
        {#each data.recentWords as word}
          <a class="premium-item" href={`${base}/admin/words/edit/${word.id}`}>
            <strong>{word.text}</strong>
            <p class="rail-copy">{word.transcription || 'No transcription'}</p>
          </a>
        {/each}
      </div>
    {:else}
      <div class="empty-card"><p>No words yet.</p></div>
    {/if}
  </section>

  <section class="composer-card">
    <div class="section-row">
      <div>
        <p class="section-kicker">Ad performance</p>
        <h2 class="subsection-title">Top tracked creatives</h2>
      </div>
      <a class="ghost-link" href={`${base}/admin/ads`}>Manage ads</a>
    </div>

    {#if data.topAds.length}
      <div class="premium-list">
        {#each data.topAds as ad}
          <a class="premium-item" href={`${base}/admin/ads/id/${ad.id}`}>
            <strong>{ad.title}</strong>
            <p class="rail-copy">
              {ad.slot} · {ad.lifecycle} · {ad.impressionCount} impressions · {ad.clickCount} clicks
            </p>
          </a>
        {/each}
      </div>
    {:else}
      <div class="empty-card"><p>No tracked ads yet.</p></div>
    {/if}
  </section>
</div>
