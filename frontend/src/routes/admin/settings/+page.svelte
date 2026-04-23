<script lang="ts">
  import { apiFormPost } from '$lib/api';
  import { base } from '$app/paths';
  import type { AdminSettingRecord, AdminSettingsResponse } from '$lib/types';

  interface Props {
    data: AdminSettingsResponse;
  }

  let { data }: Props = $props();
  let siteTitle = $state('');
  let siteSubtitle = $state('');
  let items = $state<AdminSettingRecord[]>([]);
  let message = $state('');
  let error = $state('');
  let hydrated = $state(false);

  $effect(() => {
    if (hydrated) return;
    siteTitle = data.siteIdentity.siteTitle;
    siteSubtitle = data.siteIdentity.siteSubtitle;
    items = data.items;
    hydrated = true;
  });

  async function saveIdentity() {
    message = '';
    error = '';
    try {
      const response = await apiFormPost<{ message: string; siteIdentity: { siteTitle: string; siteSubtitle: string } }>(
        '/api/admin/settings',
        new URLSearchParams({
          action: 'site-identity',
          site_title: siteTitle,
          site_subtitle: siteSubtitle
        })
      );
      siteTitle = response.siteIdentity.siteTitle;
      siteSubtitle = response.siteIdentity.siteSubtitle;
      message = response.message;
    } catch (cause) {
      error = cause instanceof Error ? cause.message : 'Failed to save site identity.';
    }
  }

  async function deleteSetting(key: string, id: number) {
    message = '';
    error = '';
    try {
      const response = await apiFormPost<{ message: string }>(
        '/api/admin/settings',
        new URLSearchParams({ action: 'delete', key })
      );
      items = items.filter((item) => item.id !== id);
      message = response.message;
    } catch (cause) {
      error = cause instanceof Error ? cause.message : 'Failed to delete setting.';
    }
  }
</script>

<div class="main-panel">
  <div class="main-panel-header">
    <p class="section-kicker">Configuration</p>
    <h1 class="section-title">Settings</h1>
    <p class="section-copy">Site identity and raw key-value configuration.</p>
  </div>

  <section class="form-card">
    <label class="field">
      <span>Site title</span>
      <input bind:value={siteTitle} class="text-input" />
    </label>
    <label class="field">
      <span>Site subtitle</span>
      <input bind:value={siteSubtitle} class="text-input" />
    </label>
    <div class="action-row">
      <button class="action-link" type="button" onclick={saveIdentity}>Save identity</button>
      <a class="ghost-link" href={`${base}/admin/settings/new`}>Create setting</a>
    </div>
    {#if message}<p class="success-text">{message}</p>{/if}
    {#if error}<p class="error-text">{error}</p>{/if}
  </section>

  <section class="composer-card">
    <div class="section-row">
      <div>
        <p class="section-kicker">Key-value store</p>
        <h2 class="subsection-title">{items.length} settings</h2>
      </div>
    </div>

    {#if items.length}
      <div class="premium-list">
        {#each items as setting}
          <article class="premium-item">
            <div class="section-row">
              <div>
                <strong>{setting.key}</strong>
                <p class="rail-copy">{setting.value}</p>
              </div>
              <div class="action-row">
                <a class="ghost-link" href={`${base}/admin/settings/id/${setting.id}`}>Edit</a>
                <button class="ghost-link" type="button" onclick={() => deleteSetting(setting.key, setting.id)}>
                  Delete
                </button>
              </div>
            </div>
          </article>
        {/each}
      </div>
    {:else}
      <div class="empty-card"><p>No settings yet.</p></div>
    {/if}
  </section>
</div>
