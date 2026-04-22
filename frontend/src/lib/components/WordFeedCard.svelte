<script lang="ts">
  import { base } from '$app/paths';
  import { initialLabel } from '$lib/format';
  import type { ApiWordSummary } from '$lib/types';

  interface Props {
    word: ApiWordSummary;
    eyebrow: string;
    copy: string;
  }

  let { word, eyebrow, copy }: Props = $props();
</script>

<a class="story-card story-card-link" href={`${base}/words/${word.id}`}>
  <div class="story-avatar">{initialLabel(word.text)}</div>
  <div class="story-body">
    <div class="story-meta">
      <strong>{eyebrow}</strong>
      {#if word.transcription}
        <span>[{word.transcription}]</span>
      {/if}
    </div>
    <p class="story-copy">
      <strong class="story-word">{word.text}</strong> {copy}
    </p>
  </div>
</a>
