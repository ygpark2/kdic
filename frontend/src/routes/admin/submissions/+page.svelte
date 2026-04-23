<script lang="ts">
  import { apiFormPost } from '$lib/api';
  import { formatTimestamp } from '$lib/format';
  import type { AdminSubmissionRecord, AdminSubmissionsResponse } from '$lib/types';

  interface Props {
    data: AdminSubmissionsResponse;
  }

  let { data }: Props = $props();
  let items = $state<AdminSubmissionRecord[]>([]);
  let message = $state('');
  let error = $state('');
  let hydrated = $state(false);

  $effect(() => {
    if (hydrated) return;
    items = data.items;
    hydrated = true;
  });

  async function moderate(id: number, action: 'approve' | 'reject') {
    message = '';
    error = '';

    try {
      const response = await apiFormPost<{ item: AdminSubmissionRecord; message: string }>(
        `/api/admin/submissions/${id}/${action}`,
        new URLSearchParams()
      );
      items = items.map((item) => (item.id === id ? response.item : item));
      message = response.message;
    } catch (cause) {
      error = cause instanceof Error ? cause.message : 'Failed to update submission.';
    }
  }
</script>

<div class="main-panel">
  <div class="main-panel-header">
    <p class="section-kicker">Review queue</p>
    <h1 class="section-title">Word submissions</h1>
    <p class="section-copy">Pending and reviewed community submissions.</p>
  </div>

  <section class="composer-card">
    {#if message}<p class="success-text">{message}</p>{/if}
    {#if error}<p class="error-text">{error}</p>{/if}

    {#if items.length}
      <div class="premium-list">
        {#each items as submission}
          <article class="premium-item">
            <div class="section-row">
              <div>
                <strong>{submission.text}</strong>
                <p class="rail-copy">
                  {submission.status} · {submission.voteCount} votes · priority {submission.priorityScore}
                </p>
                <p class="rail-copy">
                  by {submission.creator?.displayName || submission.creator?.ident || 'Unknown'} ·
                  {formatTimestamp(submission.submittedAt)}
                </p>
                {#if submission.promotedWordId}
                  <p class="rail-copy">Promoted to official word #{submission.promotedWordId}</p>
                {/if}
              </div>

              {#if submission.status === 'pending'}
                <div class="action-row">
                  <button class="action-link" type="button" onclick={() => moderate(submission.id, 'approve')}>
                    Approve
                  </button>
                  <button class="ghost-link" type="button" onclick={() => moderate(submission.id, 'reject')}>
                    Reject
                  </button>
                </div>
              {/if}
            </div>
          </article>
        {/each}
      </div>
    {:else}
      <div class="empty-card"><p>No submissions yet.</p></div>
    {/if}
  </section>
</div>
