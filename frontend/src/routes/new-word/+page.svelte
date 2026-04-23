<script lang="ts">
  import AppShell from '$lib/components/AppShell.svelte';
  import AuthPanel from '$lib/components/AuthPanel.svelte';
  import ExploreNav from '$lib/components/ExploreNav.svelte';
  import WordFeedCard from '$lib/components/WordFeedCard.svelte';
  import { apiFormPost } from '$lib/api';
  import { initialLabel } from '$lib/format';
  import type { ApiMe, ApiSession, ApiWordSubmissionSummary, ApiWordSummary } from '$lib/types';

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
  let mySubmissions = $state<ApiWordSubmissionSummary[]>([]);
  let bookmarks = $state<ApiWordSummary[]>([]);
  let hydrated = $state(false);

  $effect(() => {
    if (hydrated) return;
    mySubmissions = data.mySubmissions;
    bookmarks = data.bookmarks;
    hydrated = true;
  });

  async function submitWord() {
    formError = '';
    message = '';
    submitting = true;

    try {
      const response = await apiFormPost<{ submission: ApiWordSubmissionSummary; message: string }>(
        '/api/words',
        new URLSearchParams({
          text: wordText,
          transcription
        })
      );
      mySubmissions = [response.submission, ...mySubmissions];
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
            <strong>{mySubmissions.length}</strong>
            <span>Submissions</span>
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
      <h1 class="section-title">Submit a word for community review.</h1>
      <p class="section-copy">New words stay in the submission queue until voting and admin approval promote them into the official dictionary.</p>
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
          {submitting ? 'Submitting...' : 'Submit word'}
        </button>
      </div>
    </section>

    <section class="feed-section">
      <div class="section-row">
        <div>
          <p class="section-kicker">My submissions</p>
          <h2 class="subsection-title">Words awaiting review</h2>
        </div>
        <span class="chip">{mySubmissions.length} submissions</span>
      </div>

      {#if mySubmissions.length}
        <div class="feed-list">
          {#each mySubmissions as submission}
            <div class="story-card">
              <div class="story-avatar">{initialLabel(submission.text)}</div>
              <div class="story-body">
                <div class="story-meta">
                  <strong>{submission.status}</strong>
                  {#if submission.transcription}
                    <span>[{submission.transcription}]</span>
                  {/if}
                </div>
                <p class="story-copy">
                  <strong class="story-word">{submission.text}</strong> has {submission.voteCount} votes and is {submission.status}.
                </p>
              </div>
            </div>
          {/each}
        </div>
      {:else}
        <div class="empty-card">
          <p>You have not submitted any words yet.</p>
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
        <p class="rail-copy">Use short, unique word text first. Approved submissions become official word pages after admin review.</p>
      </section>
    </div>
  </svelte:fragment>
</AppShell>
