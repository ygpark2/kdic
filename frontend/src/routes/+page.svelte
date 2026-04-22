<script lang="ts">
  import AppShell from '$lib/components/AppShell.svelte';
  import AuthPanel from '$lib/components/AuthPanel.svelte';
  import ExploreNav from '$lib/components/ExploreNav.svelte';
  import SearchForm from '$lib/components/SearchForm.svelte';
  import StoryFeedItem from '$lib/components/StoryFeedItem.svelte';
  import { base } from '$app/paths';
  import type { ApiSession, HomeResponse } from '$lib/types';

  interface Props {
    data: HomeResponse & {
      session: ApiSession;
    };
  }

  let { data }: Props = $props();
</script>

<AppShell>
  <svelte:fragment slot="left">
    <div class="sticky-stack">
      <ExploreNav active="home" />
      <section class="rail-card rail-stack">
        <p class="rail-label">Numbers</p>
        <div class="stat-grid stat-grid-compact">
          <div class="stat-card">
            <strong>{data.stats.totalWords}</strong>
            <span>Words</span>
          </div>
          <div class="stat-card">
            <strong>{data.stats.totalStories}</strong>
            <span>Stories</span>
          </div>
          <div class="stat-card">
            <strong>{data.stats.totalMembers}</strong>
            <span>Members</span>
          </div>
        </div>
      </section>
    </div>
  </svelte:fragment>

  <section class="main-panel">
    <section class="feed-section">
      <div class="section-row">
        <div>
          <p class="section-kicker">Latest stories</p>
          <h2 class="subsection-title">Community feed</h2>
        </div>
        <span class="chip">{data.items.length} recent entries</span>
      </div>

      {#if data.items.length}
        <div class="feed-list">
          {#each data.items as item}
            <StoryFeedItem {item} />
          {/each}
        </div>
      {:else}
        <div class="empty-card">
          <p>No stories yet. The feed will appear here once members start posting.</p>
        </div>
      {/if}
    </section>
  </section>

  <svelte:fragment slot="right">
    <div class="sticky-stack">
      <AuthPanel session={data.session} />

      <section class="rail-card rail-stack">
        <p class="rail-label">Popular words</p>
        <div class="tag-cloud">
          {#each data.popularWords as word}
            <a class="tag-chip" href={`${base}/words/${word.id}`}>#{word.text}</a>
          {/each}
        </div>
      </section>

      {#if data.dailyWord}
        <section class="spotlight-card">
          <p class="rail-label">Daily word</p>
          <h3 class="spotlight-title">{data.dailyWord.text}</h3>
          {#if data.dailyWord.transcription}
            <p class="spotlight-copy">[{data.dailyWord.transcription}]</p>
          {/if}
          <a class="action-link" href={`${base}/words/${data.dailyWord.id}`}>Open entry</a>
        </section>
      {/if}
    </div>
  </svelte:fragment>
</AppShell>
