<script lang="ts">
  import { apiFormPost } from '$lib/api';
  import { base } from '$app/paths';
  import type { AdminUserRecord, AdminUsersResponse } from '$lib/types';

  interface Props {
    data: AdminUsersResponse;
  }

  let { data }: Props = $props();
  let items = $state<AdminUserRecord[]>([]);
  let message = $state('');
  let error = $state('');
  let hydrated = $state(false);

  $effect(() => {
    if (hydrated) return;
    items = data.items;
    hydrated = true;
  });

  async function deleteUser(id: number) {
    message = '';
    error = '';
    try {
      const response = await apiFormPost<{ message: string }>(
        `/api/admin/users/${id}`,
        new URLSearchParams({ action: 'delete' })
      );
      items = items.filter((item) => item.id !== id);
      message = response.message;
    } catch (cause) {
      error = cause instanceof Error ? cause.message : 'Failed to delete user.';
    }
  }
</script>

<div class="main-panel">
  <div class="main-panel-header">
    <p class="section-kicker">Accounts</p>
    <h1 class="section-title">Users</h1>
    <p class="section-copy">Manage identities, roles, and premium access.</p>
  </div>

  <section class="composer-card">
    <div class="section-row">
      <div>
        <p class="section-kicker">Directory</p>
        <h2 class="subsection-title">{items.length} users</h2>
      </div>
      <a class="action-link" href={`${base}/admin/users/new`}>Create user</a>
    </div>

    {#if message}<p class="success-text">{message}</p>{/if}
    {#if error}<p class="error-text">{error}</p>{/if}

    {#if items.length}
      <div class="premium-list">
        {#each items as user}
          <article class="premium-item">
            <div class="section-row">
              <div>
                <strong>{user.ident}</strong>
                <p class="rail-copy">
                  {user.role}{#if user.isPremium} · premium{/if}
                  {#if user.premiumBadge} · {user.premiumBadge}{/if}
                </p>
                <p class="rail-copy">{user.description || 'No description'}</p>
                {#if user.isCurrent}
                  <p class="rail-copy">Current signed-in account</p>
                {/if}
              </div>
              <div class="action-row">
                <a class="ghost-link" href={`${base}/admin/users/id/${user.id}`}>Edit</a>
                <button class="ghost-link" type="button" onclick={() => deleteUser(user.id)} disabled={user.isCurrent}>
                  Delete
                </button>
              </div>
            </div>
          </article>
        {/each}
      </div>
    {:else}
      <div class="empty-card"><p>No users yet.</p></div>
    {/if}
  </section>
</div>
