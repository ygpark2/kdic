<script lang="ts">
  import { base } from '$app/paths';

  interface Props {
    active?: 'home' | 'new-word' | null;
  }

  let { active }: Props = $props();
</script>

<section class="rail-card rail-stack">
  <p class="rail-label">Explore</p>

  <nav class="nav-stack">
    <a class:nav-item-active={active === 'home'} class="nav-item" href={`${base}/`}>Home</a>
    <a class:nav-item-active={active === 'new-word'} class="nav-item" href={`${base}/new-word`}>New word</a>
  </nav>
</section>
