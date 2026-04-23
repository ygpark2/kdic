<script lang="ts">
  import { goto } from '$app/navigation';
  import { base } from '$app/paths';
  import { apiFormPost } from '$lib/api';
  import type { AdminSettingDetailResponse } from '$lib/types';

  interface Props {
    data: AdminSettingDetailResponse;
  }

  let { data }: Props = $props();
  let value = $state('');
  let saving = $state(false);
  let message = $state('');
  let error = $state('');
  let hydrated = $state(false);

  $effect(() => {
    if (hydrated) return;
    value = data.item.value;
    hydrated = true;
  });

  async function save() {
    saving = true;
    message = '';
    error = '';

    try {
      const response = await apiFormPost<AdminSettingDetailResponse & { message: string }>(
        `/api/admin/settings/${data.item.id}`,
        new URLSearchParams({
          action: 'update',
          value
        })
      );
      value = response.item.value;
      message = response.message;
    } catch (cause) {
      error = cause instanceof Error ? cause.message : 'Failed to save setting.';
    } finally {
      saving = false;
    }
  }

  async function remove() {
    if (!confirm('Delete this setting?')) return;
    await apiFormPost(`/api/admin/settings/${data.item.id}`, new URLSearchParams({ action: 'delete' }));
    await goto(`${base}/admin/settings`);
  }
</script>

<div class="main-panel">
  <div class="main-panel-header">
    <p class="section-kicker">Configuration</p>
    <h1 class="section-title">Edit setting</h1>
    <p class="section-copy">Update the stored value for this key.</p>
  </div>

  <section class="form-card">
    <label class="field"><span>Key</span><input class="text-input" value={data.item.key} readonly /></label>
    <label class="field"><span>Value</span><input bind:value={value} class="text-input" /></label>
    {#if message}<p class="success-text">{message}</p>{/if}
    {#if error}<p class="error-text">{error}</p>{/if}
    <div class="action-row">
      <button class="action-link" type="button" onclick={save} disabled={saving}>
        {saving ? 'Saving...' : 'Save changes'}
      </button>
      <button class="ghost-link" type="button" onclick={remove}>Delete</button>
      <a class="ghost-link" href={`${base}/admin/settings`}>Back</a>
    </div>
  </section>
</div>
