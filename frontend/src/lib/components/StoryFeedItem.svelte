<script lang="ts">
  import { base } from '$app/paths';
  import { formatTimestamp, initialLabel } from '$lib/format';
  import type { ApiFeedItem } from '$lib/types';

  interface Props {
    item: ApiFeedItem;
  }

  let { item }: Props = $props();
</script>

<article class="story-card">
  <div class="story-avatar">{initialLabel(item.comment.author?.displayName || item.comment.author?.ident)}</div>
  <div class="story-body">
    <div class="story-meta">
      <strong>{item.comment.author?.displayName || item.comment.author?.ident || 'Unknown'}</strong>
      {#if item.word}
        <a class="story-word" href={`${base}/words/${item.word.id}`}>{item.word.text}</a>
      {/if}
      <span>{formatTimestamp(item.comment.createdAt)}</span>
    </div>

    <p class="story-copy">{item.comment.content}</p>
  </div>
</article>
