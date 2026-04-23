<script lang="ts">
  import { page } from '$app/state';
  import { base } from '$app/paths';
  import type { ApiSession } from '$lib/types';

  interface Props {
    session: ApiSession;
  }

  let { session }: Props = $props();
  const pathname = $derived(page.url.pathname);
  const profileHref = $derived(`${base}/profile`);
  const notificationsHref = $derived(`${base}/notifications`);
  const isProfileActive = $derived(pathname === profileHref);
  const isNotificationsActive = $derived(pathname === notificationsHref);
</script>

<section class="rail-card rail-stack">
  {#if session.authenticated && session.user}
    <p class="rail-label">Account</p>
    <h3 class="rail-title">{session.user.displayName}</h3>
    {#if session.user.isPremium}
      <span class="tag-chip">{session.user.premiumBadge || 'Premium'}</span>
    {/if}
    <p class="rail-copy">{session.user.description || 'Share word stories, keep bookmarks, and follow new definitions.'}</p>
    <div class="button-stack">
      <a class:action-link={isProfileActive} class:ghost-link={!isProfileActive} href={profileHref}>Profile</a>
      <a class:action-link={isNotificationsActive} class:ghost-link={!isNotificationsActive} href={notificationsHref}>Notifications</a>
      {#if session.user.isAdmin}
        <a class="ghost-link" href="/admin">Admin</a>
      {/if}
    </div>
  {:else}
    <p class="rail-label">Join</p>
    <h3 class="rail-title">Sign in to write stories.</h3>
    <p class="rail-copy">Keep likes, bookmarks, and profile updates in the split frontend.</p>
    <div class="button-stack">
      <a class="action-link" href={`${base}/register`}>Create account</a>
      <a class="ghost-link" href={`${base}/login`}>Log in</a>
    </div>
  {/if}
</section>
