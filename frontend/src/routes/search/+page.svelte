<script lang="ts">
  import AppShell from '$lib/components/AppShell.svelte';
  import AuthPanel from '$lib/components/AuthPanel.svelte';
  import ExploreNav from '$lib/components/ExploreNav.svelte';
  import WordResultCard from '$lib/components/WordResultCard.svelte';
  import { base } from '$app/paths';
  import type { ApiSession, SearchResponse } from '$lib/types';

  interface Props {
    data: SearchResponse & {
      q: string;
      session: ApiSession;
    };
  }

  let { data }: Props = $props();
</script>

<AppShell>
  <svelte:fragment slot="left">
    <div class="sticky-stack">
      <ExploreNav />
      <section class="rail-card rail-stack">
        <p class="rail-label">Search guide</p>
        <p class="rail-copy">Search matches official words and pending community submissions by text or transcription.</p>
      </section>
    </div>
  </svelte:fragment>

  <section class="main-panel">
    <section class="feed-section">
      <div class="section-row">
        <div>
          <p class="section-kicker">Results</p>
          <h2 class="subsection-title">
            {#if data.q}
              {data.meta.total} matches for "{data.q}"
              {#if data.meta.submissionTotal}
                <span class="chip">{data.meta.submissionTotal} submissions</span>
              {/if}
            {:else}
              Start with a word
            {/if}
          </h2>
        </div>
      </div>

      {#if data.items.length}
        <div class="stack">
          {#each data.items as word}
            <WordResultCard {word} />
          {/each}
        </div>
      {:else if data.q}
        <div class="empty-card">
          <p>No results matched that query.</p>
        </div>
      {:else}
        <div class="empty-card">
          <p>Search for a word to see definitions, examples, and stories.</p>
        </div>
      {/if}
    </section>
  </section>

  <svelte:fragment slot="right">
    <div class="sticky-stack">
      <AuthPanel session={data.session} />
      <section class="rail-card rail-stack">
        <p class="rail-label">Featured words</p>
        <div class="tag-cloud">
          {#each data.featuredWords as word}
            <a class="tag-chip" href={`${base}/words/${word.id}`}>#{word.text}</a>
          {/each}
        </div>
      </section>
    </div>
  </svelte:fragment>
</AppShell>
