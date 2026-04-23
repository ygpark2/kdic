<script lang="ts">
  import AppShell from '$lib/components/AppShell.svelte';
  import AdSlotCard from '$lib/components/AdSlotCard.svelte';
  import AuthPanel from '$lib/components/AuthPanel.svelte';
  import ExploreNav from '$lib/components/ExploreNav.svelte';
  import { apiFetch, apiFormPost } from '$lib/api';
  import { downloadSvgAsPng } from '$lib/download';
  import { formatTimestamp, initialLabel } from '$lib/format';
  import { goto } from '$app/navigation';
  import { base } from '$app/paths';
  import type {
    ApiCollection,
    ApiComment,
    ApiSession,
    CollectionWordResponse,
    PremiumNicknameResponse,
    PremiumRecommendationResponse,
    PremiumSentenceResponse,
    WordDetailResponse
  } from '$lib/types';

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
  let collections = $state<ApiCollection[]>([]);
  let content = $state('');
  let formError = $state('');
  let pendingComment = $state(false);
  let recommendationContext = $state('comfort');
  let sentenceTone = $state('gentle');
  let recommendations = $state<PremiumRecommendationResponse | null>(null);
  let sentencePack = $state<PremiumSentenceResponse | null>(null);
  let nicknamePack = $state<PremiumNicknameResponse | null>(null);
  let premiumError = $state('');
  let loadingPremium = $state(false);
  let downloadingPng = $state(false);
  let hydrated = $state(false);

  $effect(() => {
    if (hydrated) return;
    comments = data.item.comments;
    likeCount = data.item.meta.likeCount;
    bookmarkCount = data.item.meta.bookmarkCount;
    commentCount = data.item.meta.commentCount;
    liked = data.item.meta.liked;
    bookmarked = data.item.meta.bookmarked;
    collections = data.premium?.collections || [];
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

  async function toggleCollection(collection: ApiCollection) {
    if (!(await ensureAuth())) return;

    const route = collection.containsWord
      ? `/api/collections/${collection.id}/remove/${data.item.word.id}`
      : `/api/collections/${collection.id}/add/${data.item.word.id}`;
    const response = await apiFormPost<CollectionWordResponse>(route, new URLSearchParams());

    collections = collections.map((entry) =>
      entry.id === collection.id
        ? {
            ...entry,
            containsWord: response.active,
            itemCount: response.itemCount
          }
        : entry
    );
  }

  async function loadRecommendations() {
    if (!(await ensureAuth()) || !data.premium?.isPremium) return;
    loadingPremium = true;
    premiumError = '';

    try {
      recommendations = await apiFetch<PremiumRecommendationResponse>(
        fetch,
        `/api/premium/recommendations?context=${encodeURIComponent(recommendationContext)}`
      );
    } catch (error) {
      premiumError = error instanceof Error ? error.message : 'Failed to load recommendations.';
    } finally {
      loadingPremium = false;
    }
  }

  async function loadSentencePack() {
    if (!(await ensureAuth()) || !data.premium?.isPremium) return;
    loadingPremium = true;
    premiumError = '';

    try {
      sentencePack = await apiFormPost<PremiumSentenceResponse>(
        '/api/premium/sentence',
        new URLSearchParams({
          wordId: `${data.item.word.id}`,
          tone: sentenceTone
        })
      );
    } catch (error) {
      premiumError = error instanceof Error ? error.message : 'Failed to generate sentence ideas.';
    } finally {
      loadingPremium = false;
    }
  }

  async function loadNicknames() {
    if (!(await ensureAuth()) || !data.premium?.isPremium) return;
    loadingPremium = true;
    premiumError = '';

    try {
      nicknamePack = await apiFormPost<PremiumNicknameResponse>(
        '/api/premium/nickname',
        new URLSearchParams({
          wordId: `${data.item.word.id}`
        })
      );
    } catch (error) {
      premiumError = error instanceof Error ? error.message : 'Failed to generate nicknames.';
    } finally {
      loadingPremium = false;
    }
  }

  async function downloadPngCard() {
    if (!(await ensureAuth()) || !data.premium?.isPremium) return;

    downloadingPng = true;
    premiumError = '';

    try {
      await downloadSvgAsPng(
        `/api/premium/wordbook?format=svg&wordId=${data.item.word.id}`,
        `${data.item.word.text}-premium-card.png`
      );
    } catch (error) {
      premiumError = error instanceof Error ? error.message : 'Failed to export PNG card.';
    } finally {
      downloadingPng = false;
    }
  }
</script>

<svelte:head>
  <title>{data.seo?.title || `${data.item.word.text} | KDIC`}</title>
  <meta
    name="description"
    content={data.seo?.description || `Explore the definition, examples, and community stories for ${data.item.word.text}.`}
  />
  {#if data.seo?.canonicalUrl}
    <link rel="canonical" href={data.seo.canonicalUrl} />
    <meta property="og:url" content={data.seo.canonicalUrl} />
  {/if}
  <meta property="og:type" content="article" />
  <meta property="og:title" content={data.seo?.title || `${data.item.word.text} | KDIC`} />
  <meta
    property="og:description"
    content={data.seo?.description || `Explore the definition, examples, and community stories for ${data.item.word.text}.`}
  />
  {#if data.seo?.imageUrl}
    <meta property="og:image" content={data.seo.imageUrl} />
    <meta property="og:image:type" content="image/png" />
    <meta property="og:image:width" content="1200" />
    <meta property="og:image:height" content="630" />
    <meta property="og:image:alt" content={data.seo?.title || `${data.item.word.text} | KDIC`} />
  {/if}
  <meta name="twitter:card" content="summary_large_image" />
  <meta name="twitter:title" content={data.seo?.title || `${data.item.word.text} | KDIC`} />
  <meta
    name="twitter:description"
    content={data.seo?.description || `Explore the definition, examples, and community stories for ${data.item.word.text}.`}
  />
  {#if data.seo?.imageUrl}
    <meta name="twitter:image" content={data.seo.imageUrl} />
  {/if}
</svelte:head>

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

    {#if data.premium}
      <section class="composer-card">
        <div class="section-row">
          <div>
            <p class="section-kicker">Collections</p>
            <h2 class="subsection-title">Place this word into your folders.</h2>
          </div>
          <span class="chip">{collections.length} folders</span>
        </div>

        {#if collections.length}
          <div class="premium-list">
            {#each collections as collection}
              <article class="premium-item">
                <div class="section-row">
                  <div>
                    <strong>{collection.title}</strong>
                    <p class="rail-copy">{collection.itemCount} words</p>
                  </div>
                  <button class:action-link={collection.containsWord} class:ghost-link={!collection.containsWord} type="button" onclick={() => toggleCollection(collection)}>
                    {collection.containsWord ? 'Added' : 'Save'}
                  </button>
                </div>
              </article>
            {/each}
          </div>
        {:else}
          <div class="empty-card">
            <p>No collections yet. Create them on your profile page first.</p>
          </div>
        {/if}
      </section>
    {/if}

    <section class="composer-card">
      <div class="section-row">
        <div>
          <p class="section-kicker">Premium studio</p>
          <h2 class="subsection-title">Recommendations, sentences, and nickname seeds.</h2>
        </div>
        <span class="chip">{data.premium?.isPremium ? 'Unlocked' : 'Premium only'}</span>
      </div>

      {#if data.premium?.isPremium}
        <div class="premium-form-grid">
          <label class="field">
            <span>Recommendation context</span>
            <select bind:value={recommendationContext} class="text-input">
              <option value="comfort">Comfort</option>
              <option value="letter">Letter</option>
              <option value="nickname">Nickname</option>
              <option value="focus">Focus</option>
              <option value="bright">Bright</option>
            </select>
          </label>
          <label class="field">
            <span>Sentence tone</span>
            <select bind:value={sentenceTone} class="text-input">
              <option value="gentle">Gentle</option>
              <option value="warm">Warm</option>
              <option value="bold">Bold</option>
            </select>
          </label>
        </div>

        <div class="action-row">
          <button class="action-link" type="button" onclick={loadRecommendations} disabled={loadingPremium}>
            Load recommendations
          </button>
          <button class="ghost-link" type="button" onclick={loadSentencePack} disabled={loadingPremium}>
            Generate sentences
          </button>
          <button class="ghost-link" type="button" onclick={loadNicknames} disabled={loadingPremium}>
            Generate nicknames
          </button>
          <a class="ghost-link" href={`/api/premium/wordbook?format=pdf&wordId=${data.item.word.id}`}>PDF card</a>
          <a class="ghost-link" href={`/api/premium/wordbook?format=svg&wordId=${data.item.word.id}`}>Image card</a>
          <button class="ghost-link" type="button" onclick={downloadPngCard} disabled={downloadingPng}>
            {downloadingPng ? 'Rendering PNG...' : 'PNG card'}
          </button>
        </div>

        {#if premiumError}
          <p class="error-text">{premiumError}</p>
        {/if}

        {#if recommendations}
          <article class="premium-item">
            <strong>{recommendations.title}</strong>
            <p class="rail-copy">{recommendations.description}</p>
            <div class="tag-cloud">
              {#each recommendations.items as word}
                <a class="tag-chip" href={`${base}/words/${word.id}`}>{word.text}</a>
              {/each}
            </div>
          </article>
        {/if}

        {#if sentencePack}
          <article class="premium-item">
            <strong>Sentence ideas</strong>
            <div class="premium-copy-list">
              {#each sentencePack.lines as line}
                <p>{line}</p>
              {/each}
            </div>
          </article>
        {/if}

        {#if nicknamePack}
          <article class="premium-item">
            <strong>Nickname directions</strong>
            <div class="tag-cloud">
              {#each nicknamePack.names as name}
                <span class="tag-chip">{name}</span>
              {/each}
            </div>
          </article>
        {/if}
      {:else}
        <div class="empty-card">
          <p>Premium unlocks context recommendations, sentence drafts, nickname seeds, and stronger vote weight.</p>
        </div>
      {/if}
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
      {#if data.premium?.adsEnabled}
        {#if data.ads.wordRightRail}
          <AdSlotCard ad={data.ads.wordRightRail} />
        {:else}
          <section class="spotlight-card">
            <p class="rail-label">Ad spot</p>
            <p class="spotlight-copy">Premium removes this block and opens the recommendation studio for every entry.</p>
          </section>
        {/if}
      {:else}
        <section class="spotlight-card">
          <p class="rail-label">{data.quote.title}</p>
          <p class="spotlight-copy">{data.quote.body}</p>
        </section>
      {/if}

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
