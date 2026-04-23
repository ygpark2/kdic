<script lang="ts">
  import { goto } from '$app/navigation';
  import { base } from '$app/paths';
  import { apiFormPost } from '$lib/api';
  import { formatTimestamp } from '$lib/format';
  import type { AdminAdDetailResponse } from '$lib/types';

  interface Props {
    data: AdminAdDetailResponse;
  }

  let { data }: Props = $props();
  let title = $state('');
  let slot = $state('');
  let kind = $state('');
  let sortOrder = $state('0');
  let isActive = $state(false);
  let startAt = $state('');
  let endAt = $state('');
  let link = $state('');
  let ctaLabel = $state('');
  let imageUrl = $state('');
  let body = $state('');
  let embedHtml = $state('');
  let saving = $state(false);
  let message = $state('');
  let error = $state('');
  let hydrated = $state(false);

  $effect(() => {
    if (hydrated) return;
    title = data.item.title;
    slot = data.item.slot;
    kind = data.item.kind;
    sortOrder = `${data.item.sortOrder}`;
    isActive = data.item.isActive;
    startAt = data.item.startAtInput || '';
    endAt = data.item.endAtInput || '';
    link = data.item.link || '';
    ctaLabel = data.item.ctaLabel || '';
    imageUrl = data.item.imageUrl || '';
    body = data.item.body || '';
    embedHtml = data.item.embedHtml || '';
    hydrated = true;
  });

  async function save() {
    saving = true;
    message = '';
    error = '';
    const payload = new URLSearchParams({
      action: 'update',
      title,
      slot,
      kind,
      sortOrder,
      startAt,
      endAt,
      link,
      ctaLabel,
      imageUrl,
      body,
      embedHtml
    });
    if (isActive) payload.set('isActive', '1');

    try {
      const response = await apiFormPost<AdminAdDetailResponse & { message: string }>(
        `/api/admin/ads/${data.item.id}`,
        payload
      );
      message = response.message;
    } catch (cause) {
      error = cause instanceof Error ? cause.message : 'Failed to save ad.';
    } finally {
      saving = false;
    }
  }

  async function remove() {
    if (!confirm('Delete this ad?')) return;
    await apiFormPost(`/api/admin/ads/${data.item.id}`, new URLSearchParams({ action: 'delete' }));
    await goto(`${base}/admin/ads`);
  }
</script>

<div class="main-panel">
  <div class="main-panel-header">
    <p class="section-kicker">Ads</p>
    <h1 class="section-title">Edit ad</h1>
    <p class="section-copy">Update creative fields, slot targeting, and schedule.</p>
  </div>

  <section class="composer-card">
    <div class="premium-grid">
      <article class="premium-tile"><strong>Lifecycle</strong><p>{data.item.lifecycle}</p></article>
      <article class="premium-tile"><strong>Impressions</strong><p>{data.item.impressionCount}</p></article>
      <article class="premium-tile"><strong>Clicks</strong><p>{data.item.clickCount}</p></article>
      <article class="premium-tile">
        <strong>Last click</strong>
        <p>{data.item.lastClickedAt ? formatTimestamp(data.item.lastClickedAt) : 'No clicks yet'}</p>
      </article>
    </div>
  </section>

  <section class="form-card">
    <div class="premium-form-grid">
      <label class="field"><span>Title</span><input bind:value={title} class="text-input" /></label>
      <label class="field">
        <span>Slot</span>
        <select bind:value={slot} class="text-input">
          {#each data.meta.availableSlots as option}
            <option value={option.key}>{option.label}</option>
          {/each}
        </select>
      </label>
      <label class="field">
        <span>Type</span>
        <select bind:value={kind} class="text-input">
          {#each data.meta.availableKinds as option}
            <option value={option}>{option}</option>
          {/each}
        </select>
      </label>
      <label class="field"><span>Sort order</span><input bind:value={sortOrder} class="text-input" type="number" /></label>
      <label class="field"><span>Start time</span><input bind:value={startAt} class="text-input" type="datetime-local" /></label>
      <label class="field"><span>End time</span><input bind:value={endAt} class="text-input" type="datetime-local" /></label>
      <label class="field"><span>Link URL</span><input bind:value={link} class="text-input" /></label>
      <label class="field"><span>CTA label</span><input bind:value={ctaLabel} class="text-input" /></label>
      <label class="field"><span>Image URL</span><input bind:value={imageUrl} class="text-input" /></label>
    </div>
    <label class="field"><span>Custom ad body</span><textarea bind:value={body} class="text-area" rows="4"></textarea></label>
    <label class="field"><span>Embed HTML</span><textarea bind:value={embedHtml} class="text-area" rows="8"></textarea></label>
    <label class="field-checkbox"><input bind:checked={isActive} type="checkbox" /> <span>Active</span></label>
    {#if message}<p class="success-text">{message}</p>{/if}
    {#if error}<p class="error-text">{error}</p>{/if}
    <div class="action-row">
      <button class="action-link" type="button" onclick={save} disabled={saving}>
        {saving ? 'Saving...' : 'Save changes'}
      </button>
      <a class="ghost-link" href={data.item.clickUrl} target="_blank" rel="noreferrer">Tracked link</a>
      <button class="ghost-link" type="button" onclick={remove}>Delete</button>
    </div>
  </section>

  <section class="composer-card">
    <div class="section-row">
      <div>
        <p class="section-kicker">Preview</p>
        <h2 class="subsection-title">Current creative</h2>
      </div>
    </div>

    {#if kind === 'embed'}
      <iframe class="admin-preview-frame" srcdoc={embedHtml} title="Ad preview"></iframe>
    {:else}
      <article class="spotlight-card">
        <p class="rail-label">Sponsored</p>
        <h3 class="spotlight-title">{title || 'Ad title'}</h3>
        {#if imageUrl}<img class="ad-slot-image" src={imageUrl} alt={title || 'Ad image'} />{/if}
        {#if body}<p class="spotlight-copy">{body}</p>{/if}
        {#if link}<span class="action-link">{ctaLabel || 'Open sponsor'}</span>{/if}
      </article>
    {/if}
  </section>
</div>
