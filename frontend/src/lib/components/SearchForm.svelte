<script lang="ts">
  import { base } from '$app/paths';

  interface Props {
    action?: string;
    placeholder?: string;
    value?: string;
  }

  let {
    action = '/search',
    placeholder = 'Explore words...',
    value = ''
  }: Props = $props();
</script>

<form class="search-form" action={`${base}${action}`} method="GET">
  <input class="search-input" name="q" type="text" value={value} placeholder={placeholder} />
  <button class="search-button" type="submit">Search</button>
</form>
