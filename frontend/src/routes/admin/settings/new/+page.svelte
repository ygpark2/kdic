<script lang="ts">
  import { goto } from '$app/navigation';
  import { base } from '$app/paths';
  import { apiFormPost } from '$lib/api';

  let key = $state('');
  let value = $state('');
  let saving = $state(false);
  let error = $state('');

  async function save() {
    saving = true;
    error = '';
    try {
      const response = await apiFormPost<{ item: { id: number } }>(
        '/api/admin/settings',
        new URLSearchParams({
          action: 'upsert',
          key,
          value
        })
      );
      await goto(`${base}/admin/settings/id/${response.item.id}`);
    } catch (cause) {
      error = cause instanceof Error ? cause.message : 'Failed to save setting.';
    } finally {
      saving = false;
    }
  }
</script>

<div class="main-panel">
  <div class="main-panel-header">
    <p class="section-kicker">Configuration</p>
    <h1 class="section-title">Create setting</h1>
    <p class="section-copy">Add a new site-level key and value.</p>
  </div>

  <section class="form-card">
    <label class="field"><span>Key</span><input bind:value={key} class="text-input" /></label>
    <label class="field"><span>Value</span><input bind:value={value} class="text-input" /></label>
    {#if error}<p class="error-text">{error}</p>{/if}
    <div class="action-row">
      <button class="action-link" type="button" onclick={save} disabled={saving}>
        {saving ? 'Saving...' : 'Save setting'}
      </button>
      <a class="ghost-link" href={`${base}/admin/settings`}>Back</a>
    </div>
  </section>
</div>
