<script lang="ts">
  import { page } from '$app/state';
  import { base } from '$app/paths';
  import type { Snippet } from 'svelte';
  import type { ApiSession } from '$lib/types';

  interface Props {
    data: {
      session: ApiSession;
    };
    children: Snippet;
  }

  let { data, children }: Props = $props();

  const pathname = $derived(page.url.pathname);
  const navItems = [
    {
      label: 'Overview',
      href: `${base}/admin`,
      active: (value: string) => value === `${base}/admin`
    },
    {
      label: 'Ops',
      href: `${base}/admin/ops`,
      active: (value: string) => value.startsWith(`${base}/admin/ops`)
    },
    {
      label: 'Words',
      href: `${base}/admin/words`,
      active: (value: string) => value.startsWith(`${base}/admin/words`)
    },
    {
      label: 'Submissions',
      href: `${base}/admin/submissions`,
      active: (value: string) => value.startsWith(`${base}/admin/submissions`)
    },
    {
      label: 'Ads',
      href: `${base}/admin/ads`,
      active: (value: string) => value.startsWith(`${base}/admin/ads`)
    },
    {
      label: 'Users',
      href: `${base}/admin/users`,
      active: (value: string) => value.startsWith(`${base}/admin/users`)
    },
    {
      label: 'Settings',
      href: `${base}/admin/settings`,
      active: (value: string) => value.startsWith(`${base}/admin/settings`)
    }
  ];
</script>

<div class="admin-layout">
  <aside class="rail-card rail-stack admin-sidebar">
    <p class="rail-label">Admin</p>
    <h2 class="rail-title">Control room</h2>
    <p class="rail-copy">
      {data.session.user?.displayName || data.session.user?.ident || 'Administrator'}
    </p>

    <div class="button-stack">
      {#each navItems as item}
        <a class:action-link={item.active(pathname)} class:ghost-link={!item.active(pathname)} href={item.href}>
          {item.label}
        </a>
      {/each}
      <a class="ghost-link" href={`${base}/`}>Back to site</a>
    </div>
  </aside>

  <section class="admin-main">
    {@render children()}
  </section>
</div>
