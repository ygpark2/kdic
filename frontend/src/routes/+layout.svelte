<script lang="ts">
  import '../app.css';
  import type { Snippet } from 'svelte';
  import { goto, invalidateAll } from '$app/navigation';
  import { base } from '$app/paths';
  import { apiFormPost } from '$lib/api';
  import SearchForm from '$lib/components/SearchForm.svelte';
  import type { ApiSession } from '$lib/types';

  interface Props {
    data: {
      session: ApiSession;
    };
    children: Snippet;
  }

  let { data, children }: Props = $props();

  async function logout() {
    await apiFormPost('/api/auth/logout', new URLSearchParams());
    await invalidateAll();
    await goto(`${base}/`);
  }
</script>

<svelte:head>
  <link rel="preconnect" href="https://fonts.googleapis.com" />
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin="anonymous" />
  <link
    href="https://fonts.googleapis.com/css2?family=Cormorant+Garamond:wght@500;600;700&family=Space+Grotesk:wght@400;500;700&display=swap"
    rel="stylesheet"
  />
</svelte:head>

<header class="site-header">
  <div class="app-shell site-header-inner">
    <a class="brand" href={`${base}/`}>KDIC</a>
    <div class="header-search">
      <SearchForm />
    </div>

    <nav class="nav-row header-account">
      {#if data.session.authenticated && data.session.user}
        <button class="ghost-link" type="button" onclick={logout}>Sign out</button>
      {:else}
        <a class="ghost-link" href={`${base}/login`}>Log in</a>
        <a class="action-link" href={`${base}/register`}>Join</a>
      {/if}
    </nav>
  </div>
</header>

<main class="page-shell">
  <div class="app-shell">
    {@render children()}
  </div>
</main>
