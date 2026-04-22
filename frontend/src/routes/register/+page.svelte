<script lang="ts">
  import { apiFormPost } from '$lib/api';
  import { goto, invalidateAll } from '$app/navigation';
  import { base } from '$app/paths';

  let ident = $state('');
  let displayName = $state('');
  let description = $state('');
  let password = $state('');
  let passwordConfirm = $state('');
  let errorMessage = $state('');

  async function register() {
    errorMessage = '';

    try {
      await apiFormPost(
        '/api/auth/register',
        new URLSearchParams({
          ident,
          displayName,
          description,
          password,
          passwordConfirm
        })
      );
      await invalidateAll();
      await goto(`${base}/`);
    } catch (error) {
      errorMessage = error instanceof Error ? error.message : 'Failed to register.';
    }
  }
</script>

<section class="auth-card">
  <p class="section-kicker">Join KDIC</p>
  <h1 class="section-title">Create an account.</h1>
  <p class="section-copy">Keep your stories, likes, and bookmarks inside the separated frontend.</p>

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
    <textarea bind:value={description} class="text-area" rows="3"></textarea>
  </label>

  <label class="field">
    <span>Password</span>
    <input bind:value={password} class="text-input" type="password" />
  </label>

  <label class="field">
    <span>Confirm password</span>
    <input bind:value={passwordConfirm} class="text-input" type="password" />
  </label>

  {#if errorMessage}
    <p class="error-text">{errorMessage}</p>
  {/if}

  <div class="action-row">
    <button class="action-link" type="button" onclick={register}>Create account</button>
    <a class="ghost-link" href={`${base}/login`}>Log in</a>
  </div>
</section>
