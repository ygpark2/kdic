<script lang="ts">
  import { goto } from '$app/navigation';
  import { base } from '$app/paths';
  import { apiFormPost } from '$lib/api';
  import type { AdminUserDetailResponse } from '$lib/types';

  interface Props {
    data: AdminUserDetailResponse;
  }

  let { data }: Props = $props();
  let ident = $state('');
  let name = $state('');
  let description = $state('');
  let role = $state('user');
  let premiumBadge = $state('');
  let premium = $state(false);
  let password = $state('');
  let saving = $state(false);
  let message = $state('');
  let error = $state('');
  let hydrated = $state(false);

  $effect(() => {
    if (hydrated) return;
    ident = data.item.ident;
    name = data.item.name || '';
    description = data.item.description || '';
    role = data.item.role;
    premiumBadge = data.item.premiumBadge || '';
    premium = data.item.isPremium;
    hydrated = true;
  });

  async function save() {
    saving = true;
    message = '';
    error = '';
    const payload = new URLSearchParams({
      action: 'update',
      ident,
      name,
      description,
      role,
      premiumBadge,
      password
    });
    if (premium) payload.set('premium', '1');

    try {
      const response = await apiFormPost<AdminUserDetailResponse & { message: string }>(
        `/api/admin/users/${data.item.id}`,
        payload
      );
      message = response.message;
      password = '';
    } catch (cause) {
      error = cause instanceof Error ? cause.message : 'Failed to save user.';
    } finally {
      saving = false;
    }
  }

  async function remove() {
    if (!confirm('Delete this user?')) return;
    await apiFormPost(`/api/admin/users/${data.item.id}`, new URLSearchParams({ action: 'delete' }));
    await goto(`${base}/admin/users`);
  }
</script>

<div class="main-panel">
  <div class="main-panel-header">
    <p class="section-kicker">Accounts</p>
    <h1 class="section-title">Edit user</h1>
    <p class="section-copy">Update role, metadata, password, and premium access.</p>
  </div>

  <section class="form-card">
    <div class="premium-form-grid">
      <label class="field"><span>Username</span><input bind:value={ident} class="text-input" /></label>
      <label class="field"><span>Name</span><input bind:value={name} class="text-input" /></label>
      <label class="field"><span>Description</span><input bind:value={description} class="text-input" /></label>
      <label class="field"><span>Password</span><input bind:value={password} class="text-input" type="password" /></label>
      <label class="field">
        <span>Role</span>
        <select bind:value={role} class="text-input">
          <option value="user">User</option>
          <option value="admin">Admin</option>
        </select>
      </label>
      <label class="field"><span>Premium badge</span><input bind:value={premiumBadge} class="text-input" /></label>
    </div>
    <label class="field-checkbox"><input bind:checked={premium} type="checkbox" /> <span>Enable premium</span></label>
    {#if message}<p class="success-text">{message}</p>{/if}
    {#if error}<p class="error-text">{error}</p>{/if}
    <div class="action-row">
      <button class="action-link" type="button" onclick={save} disabled={saving}>
        {saving ? 'Saving...' : 'Save changes'}
      </button>
      <button class="ghost-link" type="button" onclick={remove} disabled={data.item.isCurrent}>Delete</button>
      <a class="ghost-link" href={`${base}/admin/users`}>Back</a>
    </div>
  </section>
</div>
