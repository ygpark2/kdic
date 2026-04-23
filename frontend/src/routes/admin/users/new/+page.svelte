<script lang="ts">
  import { goto } from '$app/navigation';
  import { base } from '$app/paths';
  import { apiFormPost } from '$lib/api';

  let ident = $state('');
  let password = $state('');
  let name = $state('');
  let description = $state('');
  let role = $state('user');
  let premiumBadge = $state('');
  let premium = $state(false);
  let saving = $state(false);
  let error = $state('');

  async function save() {
    saving = true;
    error = '';
    const payload = new URLSearchParams({
      ident,
      password,
      name,
      description,
      role,
      premiumBadge
    });
    if (premium) payload.set('premium', '1');

    try {
      const response = await apiFormPost<{ item: { id: number } }>(
        '/api/admin/users',
        payload
      );
      await goto(`${base}/admin/users/id/${response.item.id}`);
    } catch (cause) {
      error = cause instanceof Error ? cause.message : 'Failed to create user.';
    } finally {
      saving = false;
    }
  }
</script>

<div class="main-panel">
  <div class="main-panel-header">
    <p class="section-kicker">Accounts</p>
    <h1 class="section-title">Create user</h1>
    <p class="section-copy">Provision a new account and set its role.</p>
  </div>

  <section class="form-card">
    <div class="premium-form-grid">
      <label class="field"><span>Username</span><input bind:value={ident} class="text-input" /></label>
      <label class="field"><span>Password</span><input bind:value={password} class="text-input" type="password" /></label>
      <label class="field"><span>Name</span><input bind:value={name} class="text-input" /></label>
      <label class="field"><span>Description</span><input bind:value={description} class="text-input" /></label>
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
    {#if error}<p class="error-text">{error}</p>{/if}
    <div class="action-row">
      <button class="action-link" type="button" onclick={save} disabled={saving}>
        {saving ? 'Creating...' : 'Create user'}
      </button>
      <a class="ghost-link" href={`${base}/admin/users`}>Back</a>
    </div>
  </section>
</div>
