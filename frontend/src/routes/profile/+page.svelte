<script lang="ts">
  import AppShell from '$lib/components/AppShell.svelte';
  import AdSlotCard from '$lib/components/AdSlotCard.svelte';
  import AuthPanel from '$lib/components/AuthPanel.svelte';
  import ExploreNav from '$lib/components/ExploreNav.svelte';
  import { apiFormPost } from '$lib/api';
  import { downloadSvgAsPng } from '$lib/download';
  import { base } from '$app/paths';
  import type {
    ApiCollection,
    ApiMe,
    ApiSession,
    CollectionCreateResponse
  } from '$lib/types';

  interface Props {
    data: ApiMe & {
      session: ApiSession;
    };
  }

  let { data }: Props = $props();
  let ident = $state('');
  let displayName = $state('');
  let description = $state('');
  let collectionTitle = $state('');
  let collectionDescription = $state('');
  let message = $state('');
  let collectionMessage = $state('');
  let collectionError = $state('');
  let savingProfile = $state(false);
  let savingCollection = $state(false);
  let downloadingPng = $state(false);
  let collections = $state<ApiCollection[]>([]);
  let hydrated = $state(false);

  $effect(() => {
    if (hydrated) return;
    ident = data.user.ident;
    displayName = data.user.displayName;
    description = data.user.description || '';
    collections = data.premium.collections;
    hydrated = true;
  });

  function limitLabel(limit?: number | null) {
    return limit == null ? 'Unlimited' : `${limit} max`;
  }

  async function saveProfile() {
    savingProfile = true;
    message = '';

    try {
      const response = await apiFormPost<{ user: typeof data.user }>(
        '/api/me/update',
        new URLSearchParams({
          ident,
          displayName,
          description
        })
      );
      ident = response.user.ident;
      displayName = response.user.displayName;
      description = response.user.description || '';
      message = 'Profile updated.';
    } finally {
      savingProfile = false;
    }
  }

  async function createCollection() {
    savingCollection = true;
    collectionMessage = '';
    collectionError = '';

    try {
      const response = await apiFormPost<CollectionCreateResponse>(
        '/api/collections',
        new URLSearchParams({
          title: collectionTitle,
          description: collectionDescription
        })
      );
      collections = [response.collection, ...collections];
      collectionTitle = '';
      collectionDescription = '';
      collectionMessage = response.message;
    } catch (error) {
      collectionError = error instanceof Error ? error.message : 'Failed to create collection.';
    } finally {
      savingCollection = false;
    }
  }

  async function deleteCollection(collectionId: number) {
    await apiFormPost(`/api/collections/${collectionId}/delete`, new URLSearchParams());
    collections = collections.filter((collection) => collection.id !== collectionId);
  }

  async function downloadPngCards() {
    if (!data.premium.wordbookUrl) return;

    downloadingPng = true;
    try {
      await downloadSvgAsPng(`${data.premium.wordbookUrl}?format=svg`, 'premium-wordbook-cards.png');
    } finally {
      downloadingPng = false;
    }
  }
</script>

<AppShell>
  <svelte:fragment slot="left">
    <div class="sticky-stack">
      <ExploreNav />
      <section class="rail-card rail-stack">
        <p class="rail-label">Activity</p>
        <div class="stat-grid stat-grid-compact">
          <div class="stat-card">
            <strong>{data.meta.storyCount}</strong>
            <span>Stories</span>
          </div>
          <div class="stat-card">
            <strong>{data.meta.bookmarkCount}</strong>
            <span>Bookmarks</span>
          </div>
          <div class="stat-card">
            <strong>{data.premium.voteWeight}x</strong>
            <span>Vote weight</span>
          </div>
        </div>
      </section>
    </div>
  </svelte:fragment>

  <section class="main-panel">
    <div class="main-panel-header">
      <p class="section-kicker">Profile</p>
      <h1 class="section-title">Edit your public card.</h1>
      {#if data.premium.isPremium}
        <p class="section-copy">Premium is active. {data.premium.badge || 'Premium'} status removes ads and unlocks the creative toolset.</p>
      {:else}
        <p class="section-copy">Free accounts keep the core dictionary and social features. Premium adds unlimited saves, archives, generators, and downloads.</p>
      {/if}
    </div>

    <section class="form-card">
      <label class="field">
        <span>Username</span>
        <input bind:value={ident} class="text-input" />
      </label>

      <label class="field">
        <span>Display name</span>
        <input bind:value={displayName} class="text-input" />
      </label>

      <label class="field">
        <span>Description</span>
        <textarea bind:value={description} class="text-area" rows="4"></textarea>
      </label>

      {#if message}
        <p class="success-text">{message}</p>
      {/if}

      <div class="action-row">
        <button class="action-link" type="button" onclick={saveProfile} disabled={savingProfile}>
          {savingProfile ? 'Saving...' : 'Save profile'}
        </button>
      </div>
    </section>

    <section class="composer-card">
      <div class="section-row">
        <div>
          <p class="section-kicker">Premium plan</p>
          <h2 class="subsection-title">Paid features, visible from one card.</h2>
        </div>
        <span class:chip-live={data.premium.isPremium} class="chip">
          {data.premium.isPremium ? data.premium.badge || 'Premium' : 'Free'}
        </span>
      </div>

      <div class="premium-grid">
        <article class="premium-tile">
          <strong>Ads</strong>
          <p>{data.premium.adsEnabled ? 'Visible on free account' : 'Removed everywhere'}</p>
        </article>
        <article class="premium-tile">
          <strong>Bookmarks</strong>
          <p>{limitLabel(data.premium.bookmarkLimit)}</p>
        </article>
        <article class="premium-tile">
          <strong>Collections</strong>
          <p>{limitLabel(data.premium.collectionLimit)}</p>
        </article>
        <article class="premium-tile">
          <strong>Priority review</strong>
          <p>{data.premium.priorityReviewScore} score</p>
        </article>
      </div>
    </section>

    <section class="composer-card">
      <div class="section-row">
        <div>
          <p class="section-kicker">Collections</p>
          <h2 class="subsection-title">Folder your saved words.</h2>
        </div>
        <span class="chip">{collections.length} folders</span>
      </div>

      <div class="premium-form-grid">
        <label class="field">
          <span>Collection title</span>
          <input bind:value={collectionTitle} class="text-input" placeholder="Morning words" />
        </label>

        <label class="field">
          <span>Description</span>
          <textarea bind:value={collectionDescription} class="text-area" rows="3" placeholder="Words for calm notes, captions, or naming."></textarea>
        </label>
      </div>

      {#if collectionMessage}
        <p class="success-text">{collectionMessage}</p>
      {/if}
      {#if collectionError}
        <p class="error-text">{collectionError}</p>
      {/if}

      <div class="action-row">
        <button class="action-link" type="button" onclick={createCollection} disabled={savingCollection}>
          {savingCollection ? 'Creating...' : 'Create collection'}
        </button>
      </div>

      {#if collections.length}
        <div class="premium-list">
          {#each collections as collection}
            <article class="premium-item">
              <div class="section-row">
                <div>
                  <strong>{collection.title}</strong>
                  <p class="rail-copy">{collection.description || 'No description yet.'}</p>
                </div>
                <button class="ghost-link" type="button" onclick={() => deleteCollection(collection.id)}>
                  Delete
                </button>
              </div>
              <p class="rail-copy">{collection.itemCount} saved words</p>
              {#if collection.recentWords.length}
                <div class="tag-cloud">
                  {#each collection.recentWords as word}
                    <a class="tag-chip" href={`${base}/words/${word.id}`}>{word.text}</a>
                  {/each}
                </div>
              {/if}
            </article>
          {/each}
        </div>
      {:else}
        <div class="empty-card">
          <p>No collections yet.</p>
        </div>
      {/if}
    </section>

    <section class="composer-card">
      <div class="section-row">
        <div>
          <p class="section-kicker">Daily archive</p>
          <h2 class="subsection-title">Today and the recent rotation.</h2>
        </div>
        {#if data.premium.dailyArchiveLocked}
          <span class="chip">Preview only</span>
        {/if}
      </div>

      <div class="premium-list">
        {#each data.premium.dailyArchive as entry}
          <article class="premium-item">
            <strong>{entry.day}</strong>
            <a class="story-word" href={`${base}/words/${entry.word.id}`}>{entry.word.text}</a>
            {#if entry.note}
              <p class="rail-copy">{entry.note}</p>
            {/if}
          </article>
        {/each}
      </div>

      {#if data.premium.dailyArchiveLocked}
        <p class="rail-copy">Free accounts only see the latest preview. Premium opens the full archive.</p>
      {/if}
    </section>

    <section class="composer-card">
      <div class="section-row">
        <div>
          <p class="section-kicker">Taste report</p>
          <h2 class="subsection-title">A quick read on what you save.</h2>
        </div>
      </div>

      {#if data.premium.tasteReport}
        <div class="premium-grid">
          <article class="premium-tile">
            <strong>Style</strong>
            <p>{data.premium.tasteReport.style}</p>
          </article>
          <article class="premium-tile">
            <strong>Saved words</strong>
            <p>{data.premium.tasteReport.savedCount}</p>
          </article>
          <article class="premium-tile">
            <strong>Collections</strong>
            <p>{data.premium.tasteReport.collectionCount}</p>
          </article>
          <article class="premium-tile">
            <strong>Initials</strong>
            <p>{data.premium.tasteReport.topInitials.join(', ') || 'Not enough data'}</p>
          </article>
        </div>
        <p class="rail-copy">{data.premium.tasteReport.voice}</p>
      {:else}
        <div class="empty-card">
          <p>Premium unlocks your personal word report.</p>
        </div>
      {/if}
    </section>
  </section>

  <svelte:fragment slot="right">
    <div class="sticky-stack">
      <AuthPanel session={data.session} />

      {#if data.premium.adsEnabled}
        {#if data.ads.profileRightRail}
          <AdSlotCard ad={data.ads.profileRightRail} />
        {:else}
          <section class="spotlight-card">
            <p class="rail-label">Ad spot</p>
            <h3 class="spotlight-title">Premium removes this card.</h3>
            <p class="spotlight-copy">Use the profile as the upgrade surface until payment is connected.</p>
          </section>
        {/if}
      {:else}
        <section class="spotlight-card">
          <p class="rail-label">Wordbook</p>
          <h3 class="spotlight-title">Download your premium wordbook.</h3>
          <p class="spotlight-copy">Bookmarks and collections are packaged as text, PDF, or shareable image cards.</p>
          {#if data.premium.wordbookUrl}
            <div class="button-stack">
              <a class="action-link" href={data.premium.wordbookUrl}>Text export</a>
              <a class="ghost-link" href={`${data.premium.wordbookUrl}?format=pdf`}>PDF</a>
              <a class="ghost-link" href={`${data.premium.wordbookUrl}?format=svg`}>Image cards</a>
              <button class="ghost-link" type="button" onclick={downloadPngCards} disabled={downloadingPng}>
                {downloadingPng ? 'Rendering PNG...' : 'PNG cards'}
              </button>
            </div>
          {/if}
        </section>
      {/if}

      <section class="rail-card rail-stack">
        <p class="rail-label">Recent bookmarks</p>
        <div class="bookmark-list">
          {#if data.bookmarks.length}
            {#each data.bookmarks as word}
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
          {:else}
            <p class="rail-copy">No bookmarks yet.</p>
          {/if}
        </div>
      </section>
    </div>
  </svelte:fragment>
</AppShell>
