<script lang="ts">
  import { goto } from '$app/navigation';
  import { base } from '$app/paths';
  import { apiFormPost } from '$lib/api';
  import type { AdminAdsResponse, AdminWordDetailResponse } from '$lib/types';

  interface Props {
    data: AdminAdsResponse;
  }

  let { data }: Props = $props();
  let title = $state('');
  let slot = $state('');
  let kind = $state('');
  let sortOrder = $state('0');
  let isActive = $state(true);
  let startAt = $state('');
  let endAt = $state('');
  let link = $state('');
  let ctaLabel = $state('');
  let imageUrl = $state('');
  let body = $state('');
  let embedHtml = $state('');
  let saving = $state(false);
  let error = $state('');
  let hydrated = $state(false);

  $effect(() => {
    if (hydrated) return;
    slot = data.meta.availableSlots[0]?.key || 'home_right_rail';
    kind = data.meta.availableKinds[0] || 'custom';
    hydrated = true;
  });

  async function save() {
    saving = true;
    error = '';
    const payload = new URLSearchParams({
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
      const response = await apiFormPost<{ item: { id: number } } & { message: string }>(
        '/api/admin/ads',
        payload
      );
      await goto(`${base}/admin/ads/id/${response.item.id}`);
    } catch (cause) {
      error = cause instanceof Error ? cause.message : 'Failed to create ad.';
    } finally {
      saving = false;
    }
  }
</script>

<div class="main-panel">
  <div class="main-panel-header">
    <p class="section-kicker">Ads</p>
    <h1 class="section-title">Create ad</h1>
    <p class="section-copy">Register a slot-targeted embed or custom sponsor card.</p>
  </div>

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
    {#if error}<p class="error-text">{error}</p>{/if}
    <div class="action-row">
      <button class="action-link" type="button" onclick={save} disabled={saving}>
        {saving ? 'Creating...' : 'Create ad'}
      </button>
      <a class="ghost-link" href={`${base}/admin/ads`}>Back</a>
    </div>
  </section>
</div>
