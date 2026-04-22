<script lang="ts">
  import AppShell from '$lib/components/AppShell.svelte';
  import AuthPanel from '$lib/components/AuthPanel.svelte';
  import ExploreNav from '$lib/components/ExploreNav.svelte';
  import { apiFormPost } from '$lib/api';
  import { formatTimestamp, initialLabel } from '$lib/format';
  import { goto } from '$app/navigation';
  import { base } from '$app/paths';
  import type { ApiComment, ApiSession, WordDetailResponse } from '$lib/types';

  interface Props {
    data: WordDetailResponse & {
      session: ApiSession;
    };
  }

  let { data }: Props = $props();
  let comments = $state<ApiComment[]>([]);
  let likeCount = $state(0);
  let bookmarkCount = $state(0);
  let commentCount = $state(0);
  let liked = $state(false);
  let bookmarked = $state(false);
  let content = $state('');
  let formError = $state('');
  let pendingComment = $state(false);
  let hydrated = $state(false);

  $effect(() => {
    if (hydrated) return;
    comments = data.item.comments;
    likeCount = data.item.meta.likeCount;
    bookmarkCount = data.item.meta.bookmarkCount;
    commentCount = data.item.meta.commentCount;
    liked = data.item.meta.liked;
    bookmarked = data.item.meta.bookmarked;
    hydrated = true;
  });

  async function ensureAuth() {
    if (!data.session.authenticated) {
      await goto(`${base}/login`);
      return false;
    }

    return true;
  }

  async function toggleLike() {
    if (!(await ensureAuth())) return;
    const response = await apiFormPost<{ active: boolean; count: number }>(
      `/api/word/${data.item.word.id}/like`,
      new URLSearchParams()
    );
    liked = response.active;
    likeCount = response.count;
  }

  async function toggleBookmark() {
    if (!(await ensureAuth())) return;
    const response = await apiFormPost<{ active: boolean; count: number }>(
      `/api/word/${data.item.word.id}/bookmark`,
      new URLSearchParams()
    );
    bookmarked = response.active;
    bookmarkCount = response.count;
  }

  async function submitComment() {
    if (!(await ensureAuth())) return;

    pendingComment = true;
    formError = '';

    try {
      const response = await apiFormPost<{ comment: ApiComment }>(
        `/api/word/${data.item.word.id}/comment`,
        new URLSearchParams({ content })
      );
      comments = [response.comment, ...comments];
      commentCount += 1;
      content = '';
    } catch (error) {
      formError = error instanceof Error ? error.message : 'Failed to post the story.';
    } finally {
      pendingComment = false;
    }
  }

  async function deleteComment(commentId: number) {
    await apiFormPost(`/api/comment/${commentId}/delete`, new URLSearchParams());
    comments = comments.filter((comment) => comment.id !== commentId);
    commentCount = Math.max(0, commentCount - 1);
  }
</script>

<AppShell>
  <svelte:fragment slot="left">
    <div class="sticky-stack">
      <ExploreNav active="home" />
      <section class="rail-card rail-stack">
        <p class="rail-label">Entry stats</p>
        <div class="stat-grid stat-grid-compact">
          <div class="stat-card">
            <strong>{data.item.meta.meaningCount}</strong>
            <span>Meanings</span>
          </div>
          <div class="stat-card">
            <strong>{data.item.meta.exampleCount}</strong>
            <span>Examples</span>
          </div>
          <div class="stat-card">
            <strong>{commentCount}</strong>
            <span>Stories</span>
          </div>
        </div>
      </section>
    </div>
  </svelte:fragment>

  <section class="main-panel">
    <section class="word-hero">
      <div>
        <p class="section-kicker">Dictionary entry</p>
        <h1 class="word-hero-title">{data.item.word.text}</h1>
        {#if data.item.word.transcription}
          <p class="word-hero-subtitle">[{data.item.word.transcription}]</p>
        {/if}
      </div>

      <div class="action-row">
        <button class:chip-live={liked} class="chip chip-button" type="button" onclick={toggleLike}>
          Like {likeCount}
        </button>
        <button
          class:chip-live={bookmarked}
          class="chip chip-button"
          type="button"
          onclick={toggleBookmark}
        >
          Bookmark {bookmarkCount}
        </button>
      </div>
    </section>

    <section class="definition-list">
      {#each data.item.meanings as meaning}
        <article class="definition-card">
          <div class="definition-heading">
            <span class="tag-chip">{meaning.partOfSpeech || 'word'}</span>
          </div>
          <p class="definition-copy">{meaning.definition}</p>

          {#if meaning.examples.length}
            <div class="example-list">
              {#each meaning.examples as example}
                <div class="example-card">
                  <p>{example.sentence}</p>
                  {#if example.translation}
                    <span>{example.translation}</span>
                  {/if}
                </div>
              {/each}
            </div>
          {/if}
        </article>
      {/each}
    </section>

    <section class="composer-card">
      <div class="section-row">
        <div>
          <p class="section-kicker">Word stories</p>
          <h2 class="subsection-title">Share how you use this word.</h2>
        </div>
        <span class="chip">{commentCount} stories</span>
      </div>

      <textarea
        bind:value={content}
        class="text-area"
        rows="4"
        placeholder="Tell the community how this word appears in your work or life."
      ></textarea>

      {#if formError}
        <p class="error-text">{formError}</p>
      {/if}

      <div class="action-row">
        <button class="action-link" type="button" onclick={submitComment} disabled={pendingComment}>
          {pendingComment ? 'Posting...' : 'Post story'}
        </button>
      </div>
    </section>

    <section class="feed-section">
      {#if comments.length}
        <div class="comment-list">
          {#each comments as comment}
            <article class="comment-card">
              <div class="story-avatar">{initialLabel(comment.author?.displayName || comment.author?.ident)}</div>
              <div class="story-body">
                <div class="story-meta">
                  <strong>{comment.author?.displayName || comment.author?.ident || 'Unknown'}</strong>
                  <span>{formatTimestamp(comment.createdAt)}</span>
                </div>
                <p class="story-copy">{comment.content}</p>

                {#if comment.canManage}
                  <div class="action-row">
                    <button class="ghost-link" type="button" onclick={() => deleteComment(comment.id)}>
                      Delete
                    </button>
                  </div>
                {/if}
              </div>
            </article>
          {/each}
        </div>
      {:else}
        <div class="empty-card">
          <p>There are no stories for this word yet.</p>
        </div>
      {/if}
    </section>
  </section>

  <svelte:fragment slot="right">
    <div class="sticky-stack">
      <AuthPanel session={data.session} />
      <section class="spotlight-card">
        <p class="rail-label">{data.quote.title}</p>
        <p class="spotlight-copy">{data.quote.body}</p>
      </section>

      <section class="rail-card rail-stack">
        <p class="rail-label">Related words</p>
        <div class="bookmark-list">
          {#each data.relatedWords as word}
            <a class="bookmark-row" href={`${base}/words/${word.id}`}>
              <div class="bookmark-row-text">
                <strong>{word.text}</strong>
                {#if word.transcription}
                  <span class="bookmark-row-subtitle">[{word.transcription}]</span>
                {/if}
              </div>
              <span class="word-arrow">View</span>
            </a>
          {/each}
        </div>
      </section>
    </div>
  </svelte:fragment>
</AppShell>
