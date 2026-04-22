<script lang="ts">
  import AppShell from '$lib/components/AppShell.svelte';
  import AuthPanel from '$lib/components/AuthPanel.svelte';
  import ExploreNav from '$lib/components/ExploreNav.svelte';
  import WordFeedCard from '$lib/components/WordFeedCard.svelte';
  import { apiFormPost } from '$lib/api';
  import type { ApiMe, ApiSession, ApiWordSummary } from '$lib/types';

  interface Props {
    data: ApiMe & {
      session: ApiSession;
    };
  }

  let { data }: Props = $props();
  let wordText = $state('');
  let transcription = $state('');
  let message = $state('');
  let formError = $state('');
  let submitting = $state(false);
  let myWords = $state<ApiWordSummary[]>([]);
  let bookmarks = $state<ApiWordSummary[]>([]);
  let hydrated = $state(false);

  $effect(() => {
    if (hydrated) return;
    myWords = data.myWords;
    bookmarks = data.bookmarks;
    hydrated = true;
  });

  async function submitWord() {
    formError = '';
    message = '';
    submitting = true;

    try {
      const response = await apiFormPost<{ word: ApiWordSummary; message: string }>(
        '/api/words',
        new URLSearchParams({
          text: wordText,
          transcription
        })
      );
      myWords = [response.word, ...myWords];
      wordText = '';
      transcription = '';
      message = response.message;
    } catch (error) {
      formError = error instanceof Error ? error.message : 'Failed to add the word.';
    } finally {
      submitting = false;
    }
  }
</script>

<AppShell>
  <svelte:fragment slot="left">
    <div class="sticky-stack">
      <ExploreNav active="new-word" />
      <section class="rail-card rail-stack">
        <p class="rail-label">Library</p>
        <div class="stat-grid stat-grid-compact">
          <div class="stat-card">
            <strong>{myWords.length}</strong>
            <span>My words</span>
          </div>
          <div class="stat-card">
            <strong>{bookmarks.length}</strong>
            <span>Bookmarks</span>
          </div>
        </div>
      </section>
    </div>
  </svelte:fragment>

  <section class="main-panel">
    <div class="main-panel-header">
      <p class="section-kicker">New word</p>
      <h1 class="section-title">Add a word to your personal dictionary stream.</h1>
      <p class="section-copy">Register a new word, keep your own list, and review the words you bookmarked.</p>
    </div>

    <section class="form-card">
      <label class="field">
        <span>Word text</span>
        <input bind:value={wordText} class="text-input" maxlength="120" placeholder="Type a new word" />
      </label>

      <label class="field">
        <span>Transcription</span>
        <input bind:value={transcription} class="text-input" placeholder="Optional pronunciation" />
      </label>

      {#if formError}
        <p class="error-text">{formError}</p>
      {/if}

      {#if message}
        <p class="success-text">{message}</p>
      {/if}

      <div class="action-row">
        <button class="action-link" type="button" onclick={submitWord} disabled={submitting}>
          {submitting ? 'Saving...' : 'Register word'}
        </button>
      </div>
    </section>

    <section class="feed-section">
      <div class="section-row">
        <div>
          <p class="section-kicker">My words</p>
          <h2 class="subsection-title">Words you added</h2>
        </div>
        <span class="chip">{myWords.length} words</span>
      </div>

      {#if myWords.length}
        <div class="feed-list">
          {#each myWords as word}
            <WordFeedCard word={word} eyebrow="My word" copy="is now part of your dictionary collection." />
          {/each}
        </div>
      {:else}
        <div class="empty-card">
          <p>You have not added any words yet.</p>
        </div>
      {/if}
    </section>

    <section class="feed-section">
      <div class="section-row">
        <div>
          <p class="section-kicker">Bookmarks</p>
          <h2 class="subsection-title">Words you saved</h2>
        </div>
        <span class="chip">{bookmarks.length} saved</span>
      </div>

      {#if bookmarks.length}
        <div class="feed-list">
          {#each bookmarks as word}
            <WordFeedCard word={word} eyebrow="Bookmark" copy="is saved in your reading list." />
          {/each}
        </div>
      {:else}
        <div class="empty-card">
          <p>You have not bookmarked any words yet.</p>
        </div>
      {/if}
    </section>
  </section>

  <svelte:fragment slot="right">
    <div class="sticky-stack">
      <AuthPanel session={data.session} />
      <section class="rail-card rail-stack">
        <p class="rail-label">Tips</p>
        <p class="rail-copy">Use short, unique word text first. You can enrich definitions and stories from the word detail page later.</p>
      </section>
    </div>
  </svelte:fragment>
</AppShell>
