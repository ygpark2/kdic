<script lang="ts">
  import { goto } from '$app/navigation';
  import { base } from '$app/paths';
  import { apiFormPost } from '$lib/api';
  import type { AdminWordDetailResponse } from '$lib/types';

  let text = $state('');
  let transcription = $state('');
  let saving = $state(false);
  let error = $state('');

  async function save() {
    saving = true;
    error = '';

    try {
      const response = await apiFormPost<AdminWordDetailResponse & { message: string }>(
        '/api/admin/words',
        new URLSearchParams({
          text,
          transcription
        })
      );
      await goto(`${base}/admin/words/edit/${response.item.id}`);
    } catch (cause) {
      error = cause instanceof Error ? cause.message : 'Failed to create word.';
    } finally {
      saving = false;
    }
  }
</script>

<div class="main-panel">
  <div class="main-panel-header">
    <p class="section-kicker">Dictionary</p>
    <h1 class="section-title">Create word</h1>
    <p class="section-copy">Add a new official dictionary entry.</p>
  </div>

  <section class="form-card">
    <label class="field">
      <span>Word text</span>
      <input bind:value={text} class="text-input" />
    </label>
    <label class="field">
      <span>Transcription</span>
      <input bind:value={transcription} class="text-input" />
    </label>
    {#if error}<p class="error-text">{error}</p>{/if}
    <div class="action-row">
      <button class="action-link" type="button" onclick={save} disabled={saving}>
        {saving ? 'Creating...' : 'Create word'}
      </button>
      <a class="ghost-link" href={`${base}/admin/words`}>Back</a>
    </div>
  </section>
</div>
