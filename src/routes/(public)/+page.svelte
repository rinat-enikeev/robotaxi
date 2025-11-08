<script lang="ts">
  import {
    MapLibre,
    GeoJSONSource,
    CircleLayer,
    SymbolLayer,
    GlobeControl,
  } from "svelte-maplibre-gl"
  import maplibregl from "maplibre-gl"

  type University = {
    id: number | string
    name: string
    latitude: number | string | null
    longitude: number | string | null
    city_name?: string | null
    website?: string | null
  }
  let map = $state<maplibregl.Map | undefined>(undefined)

  let isHamburgerOpen = $state(false)
  let isUniversitiesEnabled = $state(false)
  let isUniversitiesLoading = $state(false)
  let hasFetchedUniversities = $state(false)
  let universities = $state<University[]>([])
  let universitiesError = $state<string | null>(null)

  const universitiesWithCoords = $derived(() => {
    if (!isUniversitiesEnabled) {
      return []
    }

    return universities.filter(
      (uni) => uni.longitude != null && uni.latitude != null,
    )
  })

  const universitiesGeoJson = $derived(() => ({
    type: "FeatureCollection" as const,
    features: universitiesWithCoords().map((uni) => ({
      type: "Feature" as const,
      properties: {
        id: uni.id,
        name: uni.name,
        city: uni.city_name ?? "",
        website: uni.website ?? "",
      },
      geometry: {
        type: "Point" as const,
        coordinates: [Number(uni.longitude), Number(uni.latitude)] as [
          number,
          number,
        ],
      },
    })),
  }))

  const escapeHtml = (value: string) =>
    value.replace(/[&<>"']/g, (char) => {
      switch (char) {
        case "&":
          return "&amp;"
        case "<":
          return "&lt;"
        case ">":
          return "&gt;"
        case '"':
          return "&quot;"
        case "'":
          return "&#39;"
        default:
          return char
      }
    })

  let hasSetGlobeProjection = false

  const loadUniversities = async () => {
    if (isUniversitiesLoading) return

    isUniversitiesLoading = true
    universitiesError = null

    try {
      const response = await fetch("/api/universities")
      if (!response.ok) {
        throw new Error("Failed to fetch universities")
      }

      const payload = (await response.json()) as {
        universities: University[]
      }

      universities = payload.universities ?? []
      hasFetchedUniversities = true

      const m = map
      if (m && isUniversitiesEnabled) {
        focusMapOnUniversities(m)
      }
    } catch (error) {
      const message =
        error instanceof Error ? error.message : "Unexpected error occurred"
      universitiesError = message
      hasFetchedUniversities = false
    } finally {
      isUniversitiesLoading = false
    }
  }

  const handleUniversitiesToggle = async (checked: boolean) => {
    isUniversitiesEnabled = checked

    if (checked && !hasFetchedUniversities) {
      await loadUniversities()
    }
  }

  const handleRetryUniversities = async () => {
    hasFetchedUniversities = false
    if (isUniversitiesEnabled) {
      await loadUniversities()
    }
  }

  const toggleHamburgerMenu = () => {
    isHamburgerOpen = !isHamburgerOpen
  }

  const focusMapOnUniversities = (m: maplibregl.Map) => {
    const features = universitiesWithCoords()
    if (features.length === 0) return

    const bounds = new maplibregl.LngLatBounds()
    for (const uni of features) {
      if (uni.longitude != null && uni.latitude != null) {
        bounds.extend([Number(uni.longitude), Number(uni.latitude)])
      }
    }

    if (!bounds.isEmpty()) {
      m.fitBounds(bounds, { padding: 80, maxZoom: 6 })
    }
  }

  const handleMouseEnter = () => {
    const m = map
    if (!m) return
    m.getCanvas().style.cursor = "pointer"
  }

  const handleMouseLeave = () => {
    const m = map
    if (!m) return
    m.getCanvas().style.cursor = ""
  }

  const handleUniversityClick = (event: maplibregl.MapLayerMouseEvent) => {
    const m = map
    if (!m) return

    const feature = event.features?.[0]
    if (!feature) return

    const props = feature.properties ?? {}
    const geometry = feature.geometry as {
      type: string
      coordinates: [number, number]
    }

    const coordinates = geometry.coordinates
    const rawName = props.name ? String(props.name) : "University"
    const rawCity = props.city ? String(props.city) : ""
    const rawWebsite = props.website ? String(props.website) : ""

    const name = escapeHtml(rawName)
    const city = rawCity ? escapeHtml(rawCity) : ""
    const hasProtocol = /^https?:\/\//i.test(rawWebsite)
    const websiteUrl = rawWebsite
      ? hasProtocol
        ? rawWebsite
        : `https://${rawWebsite}`
      : ""
    const websiteLabel = rawWebsite
      ? escapeHtml(rawWebsite.replace(/^https?:\/\//i, ""))
      : ""

    const details: string[] = []

    if (city) {
      details.push(`
        <div class="popup-field">
          <span class="popup-label">📍 Location</span>
          <span class="popup-value">${city}</span>
        </div>
      `)
    }

    if (websiteUrl) {
      details.push(`
        <div class="popup-field">
          <span class="popup-label">🌐 Website</span>
          <a class="popup-link" href="${websiteUrl}" target="_blank" rel="noopener noreferrer">${websiteLabel}</a>
        </div>
      `)
    }

    const html = `
      <div class="popup-content">
        <div class="popup-header">
          <h3 class="popup-title">${name}</h3>
        </div>
        <div class="popup-body">
          ${
            details.length > 0
              ? details.join("")
              : "<div class='popup-field'><span class='popup-value'>No additional details.</span></div>"
          }
        </div>
      </div>
    `

    new maplibregl.Popup({
      closeButton: true,
      closeOnClick: true,
    })
      .setLngLat(coordinates)
      .setHTML(html)
      .addTo(m)
  }

  $effect(() => {
    const m = map
    const universityCount = universitiesWithCoords().length
    const enabled = isUniversitiesEnabled

    if (!m) return

    const setup = () => {
      if (!hasSetGlobeProjection) {
        m.setProjection({ type: "globe" })
        hasSetGlobeProjection = true
      }
      if (enabled && universityCount > 0) {
        focusMapOnUniversities(m)
      }
      m.on("click", "universities-pins", handleUniversityClick)
      m.on("mouseenter", "universities-pins", handleMouseEnter)
      m.on("mouseleave", "universities-pins", handleMouseLeave)
    }

    if (!m.loaded()) {
      const onLoad = () => {
        setup()
      }
      m.once("load", onLoad)
      return () => {
        m.off("load", onLoad)
      }
    }

    setup()

    return () => {
      m.off("click", "universities-pins", handleUniversityClick)
      m.off("mouseenter", "universities-pins", handleMouseEnter)
      m.off("mouseleave", "universities-pins", handleMouseLeave)
    }
  })
</script>

<div class="map-page">
  <MapLibre
    bind:map
    class="h-full w-full"
    style="https://basemaps.cartocdn.com/gl/positron-gl-style/style.json"
    zoom={2}
    center={{ lng: 0, lat: 20 }}
  >
    <GlobeControl />

    <GeoJSONSource data={universitiesGeoJson()}>
      <CircleLayer
        id="universities-pins"
        paint={{
          "circle-radius": 6,
          "circle-color": "#2563eb",
          "circle-opacity": 0.9,
          "circle-stroke-width": 1.5,
          "circle-stroke-color": "#ffffff",
        }}
      />

      <SymbolLayer
        id="universities-labels"
        layout={{
          "text-field": ["step", ["zoom"], "", 4, ["get", "name"]],
          "text-offset": [0, 1.2],
          "text-size": 12,
          "text-font": ["Open Sans Semibold", "Arial Unicode MS Regular"],
          "text-anchor": "top",
          "text-allow-overlap": false,
        }}
        paint={{
          "text-color": "#111827",
          "text-halo-color": "#ffffff",
          "text-halo-width": 1,
          "text-opacity": ["step", ["zoom"], 0, 4, 1],
        }}
      />
    </GeoJSONSource>
  </MapLibre>

  <div class="hamburger-wrapper">
    <button
      class="floating-button hamburger-button"
      type="button"
      aria-haspopup="true"
      aria-expanded={isHamburgerOpen}
      aria-label="Toggle datasets menu"
      onclick={toggleHamburgerMenu}
    >
      <span class="hamburger-icon"></span>
      <span class="hamburger-icon"></span>
      <span class="hamburger-icon"></span>
    </button>

    {#if isHamburgerOpen}
      <div class="hamburger-menu" role="menu">
        <h2 class="menu-heading">Datasets</h2>
        <label class="menu-item">
          <input
            type="checkbox"
            checked={isUniversitiesEnabled}
            onchange={(event) =>
              handleUniversitiesToggle(
                (event.currentTarget as HTMLInputElement).checked,
              )}
          />
          <span class="menu-label">Universities</span>
        </label>

        {#if isUniversitiesLoading}
          <p class="menu-status">Loading universities…</p>
        {:else if universitiesError}
          <p class="menu-status error">Failed to load: {universitiesError}</p>
          <button
            class="retry-button"
            type="button"
            onclick={handleRetryUniversities}
          >
            Try again
          </button>
        {:else if hasFetchedUniversities}
          <p class="menu-status">
            Showing {universitiesWithCoords().length} universities
          </p>
        {/if}
      </div>
    {/if}
  </div>

  {#if isUniversitiesEnabled && hasFetchedUniversities && !isUniversitiesLoading && universitiesWithCoords().length === 0}
    <div class="empty-state">No universities available yet.</div>
  {/if}
</div>

<style>
  .map-page {
    position: fixed;
    inset: 0;
  }

  .floating-button {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 3rem;
    height: 3rem;
    border-radius: 9999px;
    background: rgba(255, 255, 255, 0.9);
    border: 1px solid rgba(17, 24, 39, 0.08);
    box-shadow: 0 12px 28px rgba(15, 23, 42, 0.18);
    cursor: pointer;
    transition:
      transform 150ms ease,
      box-shadow 150ms ease;
  }

  .floating-button:hover {
    transform: translateY(-2px);
    box-shadow: 0 18px 32px rgba(15, 23, 42, 0.22);
  }

  .hamburger-wrapper {
    position: absolute;
    top: 50%;
    right: 1.5rem;
    transform: translateY(-50%);
    z-index: 30;
    display: flex;
    flex-direction: column;
    align-items: flex-end;
    gap: 0.75rem;
  }

  .hamburger-button {
    flex-direction: column;
    gap: 0.35rem;
    padding: 0.75rem;
  }

  .hamburger-button:focus-visible,
  .floating-button:focus-visible {
    outline: 2px solid #2563eb;
    outline-offset: 2px;
  }

  .hamburger-icon {
    display: block;
    width: 1.5rem;
    height: 0.125rem;
    border-radius: 9999px;
    background: #111827;
  }

  .hamburger-menu {
    width: 16rem;
    padding: 1rem;
    border-radius: 1rem;
    background: rgba(255, 255, 255, 0.95);
    border: 1px solid rgba(17, 24, 39, 0.08);
    box-shadow: 0 18px 36px rgba(15, 23, 42, 0.2);
    backdrop-filter: blur(12px);
  }

  .menu-heading {
    margin: 0 0 0.75rem 0;
    font-size: 0.95rem;
    font-weight: 600;
    color: #111827;
  }

  .menu-item {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    font-size: 0.9rem;
    font-weight: 500;
    color: #1f2937;
  }

  .menu-item + .menu-status {
    margin-top: 0.75rem;
  }

  .menu-label {
    flex: 1;
  }

  .menu-status {
    margin: 0.75rem 0 0 0;
    font-size: 0.8rem;
    color: #374151;
  }

  .menu-status.error {
    color: #b91c1c;
  }

  .retry-button {
    margin-top: 0.5rem;
    border: none;
    border-radius: 0.5rem;
    padding: 0.5rem 0.75rem;
    background: #2563eb;
    color: #ffffff;
    font-size: 0.8rem;
    font-weight: 600;
    cursor: pointer;
  }

  .retry-button:hover {
    background: #1d4ed8;
  }

  :global(.maplibregl-ctrl-bottom-right) {
    right: auto;
    left: 1.5rem;
    bottom: 1.5rem;
    z-index: 25;
  }

  :global(.maplibregl-ctrl-bottom-right .maplibregl-ctrl-attrib-button) {
    margin: 0;
    border-radius: 9999px;
  }

  :global(
    .maplibregl-ctrl-bottom-right .maplibregl-ctrl-attrib.maplibregl-compact
  ) {
    border-radius: 0.75rem;
    box-shadow: 0 12px 28px rgba(15, 23, 42, 0.18);
  }

  .empty-state {
    position: absolute;
    top: 1.5rem;
    left: 50%;
    transform: translateX(-50%);
    background: rgba(255, 255, 255, 0.92);
    border-radius: 0.75rem;
    padding: 0.75rem 1.5rem;
    box-shadow: 0 12px 30px rgba(15, 23, 42, 0.18);
    color: #1f2937;
    font-weight: 600;
    letter-spacing: 0.01em;
  }

  :global(.maplibregl-popup-content) {
    padding: 0;
    border-radius: 12px;
    box-shadow: 0 12px 28px rgba(15, 23, 42, 0.25);
    border: 1px solid rgba(15, 23, 42, 0.08);
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto,
      "Helvetica Neue", sans-serif;
    min-width: 240px;
    max-width: 320px;
  }

  :global(.maplibregl-popup-close-button) {
    color: #6b7280;
    font-size: 18px;
    padding: 6px;
  }

  :global(.popup-content) {
    background: white;
    border-radius: 12px;
    overflow: hidden;
  }

  :global(.popup-header) {
    background: linear-gradient(135deg, #2563eb 0%, #3b82f6 100%);
    color: white;
    padding: 14px 18px;
  }

  :global(.popup-title) {
    margin: 0;
    font-size: 18px;
    font-weight: 600;
    line-height: 1.3;
  }

  :global(.popup-body) {
    padding: 16px 18px;
    display: flex;
    flex-direction: column;
    gap: 12px;
  }

  :global(.popup-field) {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }

  :global(.popup-label) {
    font-size: 12px;
    font-weight: 600;
    color: #6b7280;
    text-transform: uppercase;
    letter-spacing: 0.04em;
  }

  :global(.popup-value) {
    font-size: 14px;
    color: #1f2937;
  }

  :global(.popup-link) {
    color: #2563eb;
    text-decoration: none;
    font-weight: 500;
  }

  :global(.popup-link:hover) {
    text-decoration: underline;
  }
</style>
