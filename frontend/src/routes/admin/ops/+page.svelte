<script lang="ts">
  import type { AdminOpsResponse } from '$lib/types';

  interface Props {
    data: AdminOpsResponse;
  }

  let { data }: Props = $props();
</script>

<div class="main-panel">
  <div class="main-panel-header">
    <p class="section-kicker">Operations</p>
    <h1 class="section-title">Security, monitoring, and recovery</h1>
    <p class="section-copy">Operational runbooks and the latest audited admin actions.</p>
  </div>

  <section class="composer-card">
    <div class="section-row">
      <div>
        <p class="section-kicker">Health</p>
        <h2 class="subsection-title">Machine-readable endpoints</h2>
      </div>
    </div>

    <div class="premium-list">
      <article class="premium-item">
        <strong>/healthz</strong>
        <p class="rail-copy">Use this for uptime checks and deployment smoke tests.</p>
        <code>{data.healthUrl}</code>
      </article>
      <article class="premium-item">
        <strong>/sitemap.xml</strong>
        <p class="rail-copy">Crawler entrypoint for public dictionary pages.</p>
        <code>{data.sitemapUrl}</code>
      </article>
    </div>
  </section>

  <section class="composer-card">
    <div class="section-row">
      <div>
        <p class="section-kicker">Backup</p>
        <h2 class="subsection-title">Local recovery commands</h2>
      </div>
    </div>

    <div class="premium-list">
      <article class="premium-item">
        <strong>Create backup</strong>
        <code>{data.backupCommand}</code>
      </article>
      <article class="premium-item">
        <strong>Restore backup</strong>
        <code>{data.restoreCommand}</code>
      </article>
    </div>
  </section>

  <section class="composer-card">
    <div class="section-row">
      <div>
        <p class="section-kicker">Checklist</p>
        <h2 class="subsection-title">Deploy and monitoring runbook</h2>
      </div>
    </div>

    <div class="premium-grid">
      <article class="premium-tile">
        <strong>Deploy</strong>
        <ul class="admin-checklist">
          {#each data.deployChecklist as item}
            <li>{item}</li>
          {/each}
        </ul>
      </article>
      <article class="premium-tile">
        <strong>Monitoring</strong>
        <ul class="admin-checklist">
          {#each data.monitoringChecklist as item}
            <li>{item}</li>
          {/each}
        </ul>
      </article>
    </div>
  </section>

  <section class="composer-card">
    <div class="section-row">
      <div>
        <p class="section-kicker">Audit log</p>
        <h2 class="subsection-title">{data.recentActions.length} recent admin actions</h2>
      </div>
    </div>

    {#if data.recentActions.length}
      <div class="premium-list">
        {#each data.recentActions as action}
          <article class="premium-item">
            <div class="section-row">
              <div>
                <strong>{action.summary}</strong>
                <p class="rail-copy">
                  {action.action} · {action.targetType}
                  {#if action.targetId}
                    · {action.targetId}
                  {/if}
                </p>
              </div>
              <span class="chip">{action.createdAt}</span>
            </div>
            <p class="rail-copy">
              {action.admin?.displayName || action.admin?.ident || 'Unknown admin'}
            </p>
            {#if action.details}
              <code>{action.details}</code>
            {/if}
          </article>
        {/each}
      </div>
    {:else}
      <div class="empty-card"><p>No admin actions recorded yet.</p></div>
    {/if}
  </section>
</div>
