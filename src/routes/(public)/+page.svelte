<script lang="ts">
  import {
    MapLibre,
    GeoJSONSource,
    CircleLayer,
    SymbolLayer,
    GlobeControl,
  } from "svelte-maplibre-gl"
  import maplibregl from "maplibre-gl"
  import type { PageData } from "./$types"

  interface Props {
    data: PageData
  }

  let { data }: Props = $props()
  let map = $state<maplibregl.Map | undefined>(undefined)

  const universitiesWithCoords = $derived(() =>
    data.universities.filter(
      (uni) => uni.longitude != null && uni.latitude != null,
    ),
  )

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

    if (!m) return

    const setup = () => {
      if (!hasSetGlobeProjection) {
        m.setProjection({ type: "globe" })
        hasSetGlobeProjection = true
      }
      if (universityCount > 0) {
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

  {#if universitiesWithCoords().length === 0}
    <div class="empty-state">
      No universities available yet.
    </div>
  {/if}
</div>

<style>
  .map-page {
    position: fixed;
    inset: 0;
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

