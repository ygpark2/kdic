<script lang="ts">
  import AppShell from '$lib/components/AppShell.svelte';
  import AuthPanel from '$lib/components/AuthPanel.svelte';
  import ExploreNav from '$lib/components/ExploreNav.svelte';
  import { apiFormPost } from '$lib/api';
  import { base } from '$app/paths';
  import type { ApiMe, ApiSession } from '$lib/types';

  interface Props {
    data: ApiMe & {
      session: ApiSession;
    };
  }

  let { data }: Props = $props();
  let ident = $state('');
  let displayName = $state('');
  let description = $state('');
  let message = $state('');
  let hydrated = $state(false);

  $effect(() => {
    if (hydrated) return;
    ident = data.user.ident;
    displayName = data.user.displayName;
    description = data.user.description || '';
    hydrated = true;
  });

  async function saveProfile() {
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
            <strong>{data.meta.likeCount}</strong>
            <span>Likes</span>
          </div>
        </div>
      </section>
    </div>
  </svelte:fragment>

  <section class="main-panel">
    <div class="main-panel-header">
      <p class="section-kicker">Profile</p>
      <h1 class="section-title">Edit your public card.</h1>
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
        <button class="action-link" type="button" onclick={saveProfile}>Save profile</button>
      </div>
    </section>
  </section>

  <svelte:fragment slot="right">
    <div class="sticky-stack">
      <AuthPanel session={data.session} />
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
