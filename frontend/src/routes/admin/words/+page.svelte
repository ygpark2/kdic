<script lang="ts">
  import { base } from '$app/paths';
  import type { AdminWordsResponse } from '$lib/types';

  interface Props {
    data: AdminWordsResponse;
  }

  let { data }: Props = $props();
</script>

<div class="main-panel">
  <div class="main-panel-header">
    <p class="section-kicker">Dictionary</p>
    <h1 class="section-title">Words</h1>
    <p class="section-copy">Official dictionary entries managed from the frontend.</p>
  </div>

  <section class="composer-card">
    <div class="section-row">
      <div>
        <p class="section-kicker">Entries</p>
        <h2 class="subsection-title">{data.items.length} words</h2>
      </div>
      <a class="action-link" href={`${base}/admin/words/new`}>Create word</a>
    </div>

    {#if data.items.length}
      <div class="premium-list">
        {#each data.items as word}
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
</div>
