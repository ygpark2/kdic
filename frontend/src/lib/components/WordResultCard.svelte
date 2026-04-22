<script lang="ts">
  import { base } from '$app/paths';
  import type { ApiWordSummary } from '$lib/types';

  interface Props {
    word: ApiWordSummary;
  }

  let { word }: Props = $props();
</script>

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
