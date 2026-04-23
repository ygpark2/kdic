<script lang="ts">
  import { base } from '$app/paths';
  import type { ApiSearchResult } from '$lib/types';

  interface Props {
    word: ApiSearchResult;
  }

  let { word }: Props = $props();
</script>

{#if word.kind === 'submission'}
  <div class="word-card word-card-muted">
    <div>
      <p class="word-kicker">User submission</p>
      <h3 class="word-title">{word.text}</h3>
      {#if word.transcription}
        <p class="word-subtitle">[{word.transcription}]</p>
      {/if}
      <p class="word-subtitle">{word.voteCount} votes · awaiting review</p>
    </div>

    <span class="word-arrow">Pending</span>
  </div>
{:else}
  <a class="word-card" href={`${base}/words/${word.id}`}>
    <div>
      <p class="word-kicker">Dictionary entry</p>
      <h3 class="word-title">{word.text}</h3>
      {#if word.transcription}
        <p class="word-subtitle">[{word.transcription}]</p>
      {/if}
    </div>

    <span class="word-arrow">View</span>
  </a>
{/if}
