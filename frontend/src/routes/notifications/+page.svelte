<script lang="ts">
  import AppShell from '$lib/components/AppShell.svelte';
  import AuthPanel from '$lib/components/AuthPanel.svelte';
  import ExploreNav from '$lib/components/ExploreNav.svelte';
  import { apiFormPost } from '$lib/api';
  import { formatTimestamp } from '$lib/format';
  import { base } from '$app/paths';
  import type { ApiNotification, ApiSession, NotificationsResponse } from '$lib/types';

  interface Props {
    data: NotificationsResponse & {
      session: ApiSession;
    };
  }

  let { data }: Props = $props();
  let notifications = $state<ApiNotification[]>([]);
  let unreadCount = $state(0);
  let hydrated = $state(false);

  $effect(() => {
    if (hydrated) return;
    notifications = data.items;
    unreadCount = data.meta.unreadCount;
    hydrated = true;
  });

  async function markAllRead() {
    await apiFormPost('/api/notifications/read-all', new URLSearchParams());
    notifications = notifications.map((item) => ({ ...item, isRead: true }));
    unreadCount = 0;
  }
</script>

<AppShell>
  <svelte:fragment slot="left">
    <div class="sticky-stack">
      <ExploreNav />
      <section class="rail-card rail-stack">
        <p class="rail-label">Status</p>
        <div class="stat-grid stat-grid-compact">
          <div class="stat-card">
            <strong>{unreadCount}</strong>
            <span>Unread</span>
          </div>
          <div class="stat-card">
            <strong>{notifications.length}</strong>
            <span>Total</span>
          </div>
        </div>
      </section>
    </div>
  </svelte:fragment>

  <section class="main-panel">
    <div class="main-panel-header">
      <div class="section-row">
        <div>
          <p class="section-kicker">Inbox</p>
          <h1 class="section-title">Notifications</h1>
        </div>
        <button class="action-link" type="button" onclick={markAllRead}>Mark all read</button>
      </div>
    </div>

    {#if notifications.length}
      <div class="notification-list">
        {#each notifications as notification}
          <article class:notification-read={notification.isRead} class="notification-card">
            <div class="story-avatar">{notification.actor?.displayName?.[0] || notification.actor?.ident?.[0] || 'N'}</div>
            <div class="story-body">
              <div class="story-meta">
                <strong>{notification.kind}</strong>
                <span>{formatTimestamp(notification.createdAt)}</span>
              </div>
              <p class="story-copy">
                {#if notification.actor}
                  {notification.actor.displayName}
                {:else}
                  Someone
                {/if}
                {#if notification.word}
                  {' '}interacted around <strong>{notification.word}</strong>.
                {/if}
              </p>
            </div>
          </article>
        {/each}
      </div>
    {:else}
      <div class="empty-card">
        <p>No notifications yet.</p>
      </div>
    {/if}
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
    </div>
  </svelte:fragment>
</AppShell>
