<script lang="ts">
  import { WebsiteName } from "./../../config"
  import "../../app.css"

  interface Props {
    children?: import("svelte").Snippet
  }

  let { children }: Props = $props()
</script>

<div class="">
  {@render children?.()}
</div>

<!-- Spacer grows so the footer can be at bottom on short pages -->
<div class="grow"></div>

<footer class="py-16 bg-primary/10 text-center text-sm text-base-content/60">
  <div class="max-w-5xl mx-auto space-y-4">
    <p>
      Built with <a href="https://kit.svelte.dev" class="link font-bold"
        >SvelteKit</a
      >,
      <a href="https://supabase.com" class="link font-bold">Supabase</a> and
      <a href="https://maplibre.org" class="link font-bold">MapLibre</a>.
    </p>
    <p>
      Open data sourced from public company reports, regulatory filings, and
      volunteer contributors.
    </p>
    <p class="text-xs">© 2025 Robotaxi Directory.</p>
  </div>
</footer>
