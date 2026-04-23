<script lang="ts">
  import { base } from '$app/paths';
  import { apiFormPost } from '$lib/api';
  import type { AdminWordDetailResponse } from '$lib/types';

  interface Props {
    data: AdminWordDetailResponse;
  }

  let { data }: Props = $props();
  let text = $state('');
  let transcription = $state('');
  let saving = $state(false);
  let message = $state('');
  let error = $state('');
  let hydrated = $state(false);

  $effect(() => {
    if (hydrated) return;
    text = data.item.text;
    transcription = data.item.transcription || '';
    hydrated = true;
  });

  async function save() {
    saving = true;
    message = '';
    error = '';

    try {
      const response = await apiFormPost<AdminWordDetailResponse & { message: string }>(
        `/api/admin/words/${data.item.id}`,
        new URLSearchParams({
          text,
          transcription
        })
      );
      text = response.item.text;
      transcription = response.item.transcription || '';
      message = response.message;
    } catch (cause) {
      error = cause instanceof Error ? cause.message : 'Failed to save word.';
    } finally {
      saving = false;
    }
  }
</script>

<div class="main-panel">
  <div class="main-panel-header">
    <p class="section-kicker">Dictionary</p>
    <h1 class="section-title">Edit word</h1>
    <p class="section-copy">Update the text and transcription for this entry.</p>
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
    {#if message}<p class="success-text">{message}</p>{/if}
    {#if error}<p class="error-text">{error}</p>{/if}
    <div class="action-row">
      <button class="action-link" type="button" onclick={save} disabled={saving}>
        {saving ? 'Saving...' : 'Save changes'}
      </button>
      <a class="ghost-link" href={`${base}/admin/words`}>Back</a>
    </div>
  </section>
</div>
