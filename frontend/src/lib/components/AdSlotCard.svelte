<script lang="ts">
  import { baseUrl } from '$lib/api';
  import type { ApiAd } from '$lib/types';
  import { onMount } from 'svelte';

  interface Props {
    ad: ApiAd;
  }

  let { ad }: Props = $props();
  let trackedHref = $derived(ad.clickUrl || ad.link || null);
  let embedDocument = $derived(buildEmbedDocument(ad.embedHtml || ''));

  onMount(() => {
    const pathKey = typeof window !== 'undefined' ? window.location.pathname : 'unknown';
    const impressionKey = `kdic-ad-impression:${ad.id}:${pathKey}`;

    try {
      if (sessionStorage.getItem(impressionKey)) return;
      sessionStorage.setItem(impressionKey, '1');
    } catch {
      // Ignore sessionStorage failures and continue tracking once per mount.
    }

    void fetch(`${baseUrl}/api/ads/${ad.id}/impression`, {
      method: 'POST',
      credentials: 'include'
    }).catch(() => {
      // Ad telemetry should not interrupt the page.
    });
  });

  function buildEmbedDocument(embedHtml: string) {
    return `<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src https: data:; style-src 'unsafe-inline' https:; script-src 'unsafe-inline' https://pagead2.googlesyndication.com https://partner.googleadservices.com https://www.googletagservices.com https://www.google.com; connect-src https:; frame-src https:; font-src https: data:;" />
    <style>
      html, body {
        margin: 0;
        padding: 0;
        background: transparent;
        overflow: hidden;
      }
      body {
        font-family: 'Space Grotesk', sans-serif;
      }
    </style>
  </head>
  <body>${embedHtml}</body>
</html>`;
  }
</script>

{#if ad.kind === 'embed'}
  <section class="spotlight-card ad-slot-card">
    <p class="rail-label">Sponsored</p>
    <iframe
      class="ad-slot-embed-frame"
      sandbox="allow-scripts allow-same-origin allow-popups allow-popups-to-escape-sandbox"
      loading="lazy"
      referrerpolicy="strict-origin-when-cross-origin"
      srcdoc={embedDocument}
      title={ad.title}
    ></iframe>
  </section>
{:else}
  <section class="spotlight-card ad-slot-card">
    <p class="rail-label">Sponsored</p>
    <h3 class="spotlight-title">{ad.title}</h3>
    {#if ad.imageUrl}
      <img class="ad-slot-image" src={ad.imageUrl} alt={ad.title} />
    {/if}
    {#if ad.body}
      <p class="spotlight-copy">{ad.body}</p>
    {/if}
    {#if trackedHref}
      <a class="action-link" href={trackedHref} rel="noreferrer" target="_blank">
        {ad.ctaLabel || 'Open sponsor'}
      </a>
    {/if}
  </section>
{/if}
