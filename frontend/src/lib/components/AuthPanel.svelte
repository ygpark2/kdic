<script lang="ts">
  import { base } from '$app/paths';
  import type { ApiSession } from '$lib/types';

  interface Props {
    session: ApiSession;
  }

  let { session }: Props = $props();
</script>

<section class="rail-card rail-stack">
  {#if session.authenticated && session.user}
    <p class="rail-label">Account</p>
    <h3 class="rail-title">{session.user.displayName}</h3>
    <p class="rail-copy">{session.user.description || 'Share word stories, keep bookmarks, and follow new definitions.'}</p>
    <div class="button-stack">
      <a class="action-link" href={`${base}/profile`}>Profile</a>
      <a class="ghost-link" href={`${base}/notifications`}>Notifications</a>
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
