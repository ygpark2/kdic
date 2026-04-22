<script lang="ts">
  import { apiFormPost } from '$lib/api';
  import { goto, invalidateAll } from '$app/navigation';
  import { base } from '$app/paths';

  let ident = $state('');
  let password = $state('');
  let errorMessage = $state('');

  async function login() {
    errorMessage = '';

    try {
      await apiFormPost('/api/auth/login', new URLSearchParams({ ident, password }));
      await invalidateAll();
      await goto(`${base}/`);
    } catch (error) {
      errorMessage = error instanceof Error ? error.message : 'Failed to log in.';
    }
  }
</script>

<section class="auth-card">
  <p class="section-kicker">Authentication</p>
  <h1 class="section-title">Log in to KDIC.</h1>
  <p class="section-copy">The frontend is split out, but the session still comes from Yesod.</p>

  <label class="field">
    <span>Username</span>
    <input bind:value={ident} class="text-input" />
  </label>

  <label class="field">
    <span>Password</span>
    <input bind:value={password} class="text-input" type="password" />
  </label>

  {#if errorMessage}
    <p class="error-text">{errorMessage}</p>
  {/if}

  <div class="action-row">
    <button class="action-link" type="button" onclick={login}>Sign in</button>
    <a class="ghost-link" href={`${base}/register`}>Create account</a>
  </div>
</section>
