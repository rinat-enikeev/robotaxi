<script lang="ts">
  import { onMount, tick } from "svelte"
  import { DeckGLOverlay } from "@svelte-maplibre-gl/deckgl"
  import { ColumnLayer, TextLayer } from "@deck.gl/layers"
  import { COORDINATE_SYSTEM } from "@deck.gl/core"
  import {
    MapLibre,
    GeoJSONSource,
    CircleLayer,
    SymbolLayer,
    FillLayer,
    LineLayer,
    GlobeControl,
  } from "svelte-maplibre-gl"
  import maplibregl from "maplibre-gl"
  import type {
    Feature,
    FeatureCollection,
    MultiPolygon,
    Polygon,
  } from "geojson"

  type Robotaxi = {
    id: number
    slug: string
    name: string
    website: string | null
    latitude: number
    longitude: number
    address: string | null
    city_slug: string
    country_slug: string
  }

  type University = {
    id: number | string
    name: string
    latitude: number | string | null
    longitude: number | string | null
    city_name?: string | null
    website?: string | null
  }

  type Ridehailing = {
    id: number
    slug: string
    name: string
    website: string | null
    latitude: number
    longitude: number
    address: string | null
    city_slug: string
    country_slug: string
  }

  type RidehailingFeatureProperties = {
    id: number
    name: string
    website: string
    address: string
    slug: string
    sanitizedWebsite: string
    imageName: string | null
  }

  type RidehailingCountryOperation = {
    ridehailing_slug: string
    country_slug: string
    iso_alpha_2: string | null
    iso_alpha_3: string | null
  }

  type RidehailingCityOperation = {
    ridehailing_slug: string
    city_slug: string
    city_name: string
    country_slug: string | null
    latitude: number | null
    longitude: number | null
    population: number | null
  }

  type RidehailingCityOperationPayload = {
    ridehailing_slug: string
    city_slug: string
    city_name: string
    country_slug: string | null
    latitude: number | null
    longitude: number | null
    population: number | null
  }

  type RidehailingCityOperationDeckDatum = {
    ridehailing_slug: string
    city_slug: string
    city_name: string
    latitude: number
    longitude: number
    elevation: number
    fillColor: [number, number, number, number]
  }

  type RidehailingOperationFeatureProperties = {
    ridehailing_slug: string
    name: string
    iso_alpha_3: string
  }

  type CountryFeatureProperties = {
    name: string
    "ISO3166-1-Alpha-3": string
    "ISO3166-1-Alpha-2": string
  }

  type CountryFeatureCollection = FeatureCollection<
    Polygon | MultiPolygon,
    CountryFeatureProperties
  >

  type RobotaxiFeatureProperties = {
    id: number
    name: string
    website: string
    address: string
    slug: string
    imageName: string | null
    sanitizedWebsite: string
  }

  let map = $state<maplibregl.Map | undefined>(undefined)

  let isHamburgerOpen = $state(false)

  let isRobotaxisEnabled = $state(false)
  let isRobotaxisLoading = $state(false)
  let hasFetchedRobotaxis = $state(false)
  let robotaxis = $state<Robotaxi[]>([])
  let robotaxisError = $state<string | null>(null)

  let isRidehailingsEnabled = $state(true)
  let isRidehailingsLoading = $state(false)
  let hasFetchedRidehailings = $state(false)
  let ridehailings = $state<Ridehailing[]>([])
  let ridehailingsError = $state<string | null>(null)

  let isUniversitiesEnabled = $state(false)
  let isUniversitiesLoading = $state(false)
  let hasFetchedUniversities = $state(false)
  let universities = $state<University[]>([])
  let universitiesError = $state<string | null>(null)

  let isRidehailingOperationsEnabled = $state(true)
  let isRidehailingOperationsLoading = $state(false)
  let hasFetchedRidehailingOperations = $state(false)
  let ridehailingCountryOperations = $state<RidehailingCountryOperation[]>([])
  let ridehailingCityOperations = $state<RidehailingCityOperation[]>([])
  let ridehailingOperationsError = $state<string | null>(null)
  let ridehailingOperationVisibilityBySlug = $state<Record<string, boolean>>({})
  let ridehailingCityVisibilityBySlug = $state<Record<string, boolean>>({})

  let isCountryBoundariesLoading = $state(false)
  let countryBoundariesError = $state<string | null>(null)
  let countriesGeoJson = $state<CountryFeatureCollection | null>(null)

  const sanitizeWebsite = (value: string) => {
    const trimmed = value.trim()
    if (!trimmed) return ""
    return trimmed.replace(/^https?:\/\//i, "").replace(/\/+$/, "")
  }

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

  const robotaxisWithCoords = $derived(() => {
    if (!isRobotaxisEnabled) {
      return []
    }

    return robotaxis.filter(
      (company) => company.longitude != null && company.latitude != null,
    )
  })

  const robotaxiGeoJson = $derived(() => ({
    type: "FeatureCollection" as const,
    features: robotaxisWithCoords().map((company) => {
      const website = (company.website ?? "").trim()
      const sanitizedWebsite = website ? sanitizeWebsite(website) : ""
      const imageName =
        sanitizedWebsite !== "" ? `robotaxi-${company.slug}` : null

      return {
        type: "Feature" as const,
        properties: {
          id: company.id,
          name: company.name,
          website,
          address: company.address ?? "",
          slug: company.slug,
          imageName,
          sanitizedWebsite,
        },
        geometry: {
          type: "Point" as const,
          coordinates: [
            Number(company.longitude),
            Number(company.latitude),
          ] as [number, number],
        },
      }
    }),
  }))

  const ridehailingsWithCoords = $derived(() => {
    if (!isRidehailingsEnabled) {
      return []
    }

    return ridehailings.filter(
      (company) => company.longitude != null && company.latitude != null,
    )
  })

  const ridehailingGeoJson = $derived(() => ({
    type: "FeatureCollection" as const,
    features: ridehailingsWithCoords().map((company) => {
      const website = (company.website ?? "").trim()
      const sanitizedWebsite = website ? sanitizeWebsite(website) : ""
      const imageName =
        sanitizedWebsite !== "" ? `ridehailing-${company.slug}` : null

      return {
        type: "Feature" as const,
        properties: {
          id: company.id,
          name: company.name,
          website,
          address: company.address ?? "",
          slug: company.slug,
          sanitizedWebsite,
          imageName,
        },
        geometry: {
          type: "Point" as const,
          coordinates: [
            Number(company.longitude),
            Number(company.latitude),
          ] as [number, number],
        },
      }
    }),
  }))

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

  const buildRobotaxiLogoUrl = (website: string) =>
    `https://img.logo.dev/${encodeURIComponent(
      website,
    )}?size=128&format=png&circular=true&token=pk_Yu3KDenwQuy7Mr1I3USKIA`

  const buildRidehailingLogoUrl = (website: string) =>
    `https://img.logo.dev/${encodeURIComponent(
      website,
    )}?size=128&format=png&circular=true&token=pk_Yu3KDenwQuy7Mr1I3USKIA`

  const robotaxiLogos = $derived(() =>
    robotaxiGeoJson()
      .features.map(
        (feature) => feature.properties as RobotaxiFeatureProperties,
      )
      .filter(
        (props) => props.imageName !== null && props.sanitizedWebsite !== "",
      )
      .map((props) => ({
        imageName: props.imageName as string,
        logoUrl: buildRobotaxiLogoUrl(props.sanitizedWebsite),
      })),
  )

  const robotaxiLogoMap = $derived(() => {
    const entries = new Map<string, string>()
    for (const { imageName, logoUrl } of robotaxiLogos()) {
      entries.set(imageName, logoUrl)
    }
    return entries
  })

  const ridehailingLogos = $derived(() =>
    ridehailingGeoJson()
      .features.map(
        (feature) => feature.properties as RidehailingFeatureProperties,
      )
      .filter(
        (props) => props.imageName !== null && props.sanitizedWebsite !== "",
      )
      .map((props) => ({
        imageName: props.imageName as string,
        logoUrl: buildRidehailingLogoUrl(props.sanitizedWebsite),
      })),
  )

  const ridehailingLogoMap = $derived(() => {
    const entries = new Map<string, string>()
    for (const { imageName, logoUrl } of ridehailingLogos()) {
      entries.set(imageName, logoUrl)
    }
    return entries
  })

  const ridehailingColorPalette = [
    { fill: "#16a34a", outline: "#15803d" },
    { fill: "#0ea5e9", outline: "#0369a1" },
    { fill: "#f97316", outline: "#ea580c" },
    { fill: "#9333ea", outline: "#7e22ce" },
    { fill: "#f59e0b", outline: "#d97706" },
    { fill: "#ec4899", outline: "#db2777" },
    { fill: "#22c55e", outline: "#16a34a" },
    { fill: "#6366f1", outline: "#4f46e5" },
  ] as const

  const CITY_COLUMN_RADIUS_METERS = 18000
  const CITY_COLUMN_POPULATION_SCALE = 0.2
  const CITY_LABEL_VERTICAL_OFFSET = 2200
  const DEFAULT_COLUMN_RGB: [number, number, number] = [75, 85, 99]

  const hexToRgb = (value: string): [number, number, number] => {
    const normalized = value.trim().replace(/^#/, "")
    if (normalized.length === 0) {
      return DEFAULT_COLUMN_RGB
    }

    let hex = normalized
    if (hex.length === 3) {
      hex = hex
        .split("")
        .map((char) => char + char)
        .join("")
    }

    if (hex.length !== 6) {
      return DEFAULT_COLUMN_RGB
    }

    const int = Number.parseInt(hex, 16)
    if (Number.isNaN(int)) {
      return DEFAULT_COLUMN_RGB
    }

    return [(int >> 16) & 255, (int >> 8) & 255, int & 255]
  }

  const computeCityElevation = (population: number | null): number => {
    if (!population || population <= 0) {
      return 0
    }

    const height = population * CITY_COLUMN_POPULATION_SCALE
    return Number.isFinite(height) ? height : 0
  }

  const ridehailingCountryCounts = $derived(() => {
    const counts = new Map<string, number>()
    for (const record of ridehailingCountryOperations) {
      const slug = record.ridehailing_slug
      counts.set(slug, (counts.get(slug) ?? 0) + 1)
    }
    return counts
  })

  const ridehailingCityCounts = $derived(() => {
    const counts = new Map<string, number>()
    for (const record of ridehailingCityOperations) {
      const slug = record.ridehailing_slug
      counts.set(slug, (counts.get(slug) ?? 0) + 1)
    }
    return counts
  })

  const ridehailingCountryIsoCodesBySlug = $derived(() => {
    const map = new Map<string, { alpha2: Set<string>; alpha3: Set<string> }>()

    for (const record of ridehailingCountryOperations) {
      const slug = record.ridehailing_slug
      const entry = map.get(slug) ?? {
        alpha2: new Set<string>(),
        alpha3: new Set<string>(),
      }

      const isoAlpha2 = record.iso_alpha_2
      if (isoAlpha2) {
        entry.alpha2.add(isoAlpha2.toUpperCase())
      }

      const isoAlpha3 = record.iso_alpha_3
      if (isoAlpha3) {
        entry.alpha3.add(isoAlpha3.toUpperCase())
      }

      map.set(slug, entry)
    }

    return map
  })

  const emptyRidehailingOperationsGeoJson: FeatureCollection<
    Polygon | MultiPolygon,
    RidehailingOperationFeatureProperties
  > = {
    type: "FeatureCollection",
    features: [],
  }

  const ridehailingOperationsGeoJson = $derived(() => {
    if (!isRidehailingOperationsEnabled) {
      return emptyRidehailingOperationsGeoJson
    }

    const geoJson = countriesGeoJson
    if (!geoJson) {
      return emptyRidehailingOperationsGeoJson
    }

    const isoCodes = ridehailingCountryIsoCodesBySlug()
    if (isoCodes.size === 0) {
      return emptyRidehailingOperationsGeoJson
    }

    const features: Feature<
      Polygon | MultiPolygon,
      RidehailingOperationFeatureProperties
    >[] = []

    for (const feature of geoJson.features) {
      const properties = feature.properties
      if (!properties) continue

      const isoAlpha3 =
        properties["ISO3166-1-Alpha-3"]?.toUpperCase() ??
        properties["ISO3166-1-Alpha-2"]?.toUpperCase()
      if (!isoAlpha3) continue

      for (const [slug, codes] of isoCodes.entries()) {
        if (
          codes.alpha3.has(isoAlpha3) ||
          codes.alpha2.has(properties["ISO3166-1-Alpha-2"]?.toUpperCase() ?? "")
        ) {
          features.push({
            type: "Feature" as const,
            properties: {
              ridehailing_slug: slug,
              name: properties.name,
              iso_alpha_3: isoAlpha3,
            },
            geometry: feature.geometry,
          })
        }
      }
    }

    return {
      type: "FeatureCollection" as const,
      features,
    }
  })

  const ridehailingColorsBySlug = $derived(() => {
    const colors = new Map<string, { fill: string; outline: string }>()
    const palette = ridehailingColorPalette
    const slugSet = new Set<string>()

    for (const record of ridehailingCountryOperations) {
      slugSet.add(record.ridehailing_slug)
    }

    for (const record of ridehailingCityOperations) {
      slugSet.add(record.ridehailing_slug)
    }

    const slugs = Array.from(slugSet).sort()

    let index = 0
    for (const slug of slugs) {
      const paletteColor = palette[index % palette.length]
      colors.set(slug, paletteColor)
      index += 1
    }

    return colors
  })

  const ridehailingOperationCompanies = $derived(() => {
    const countryCounts = ridehailingCountryCounts()
    const cityCounts = ridehailingCityCounts()
    const slugSet = new Set<string>()

    for (const slug of countryCounts.keys()) {
      slugSet.add(slug)
    }

    for (const slug of cityCounts.keys()) {
      slugSet.add(slug)
    }

    if (slugSet.size === 0) {
      return []
    }

    return Array.from(slugSet)
      .map((slug) => {
        const companyName =
          ridehailings.find((company) => company.slug === slug)?.name ?? slug

        return {
          slug,
          name: companyName,
          countryCount: countryCounts.get(slug) ?? 0,
          cityCount: cityCounts.get(slug) ?? 0,
        }
      })
      .sort((a, b) =>
        a.name.localeCompare(b.name, undefined, { sensitivity: "base" }),
      )
  })

  const activeRidehailingOperationSlugs = $derived(() => {
    const visibility = ridehailingOperationVisibilityBySlug
    const companies = ridehailingOperationCompanies()
    if (companies.length === 0) {
      return []
    }

    const result: string[] = []
    for (const company of companies) {
      const isVisible = visibility[company.slug]
      if (isVisible === undefined || isVisible) {
        result.push(company.slug)
      }
    }

    if (result.length > 0) {
      return result
    }

    return []
  })

  const activeRidehailingCityOperationSlugs = $derived(() => {
    const visibility = ridehailingCityVisibilityBySlug
    const companies = ridehailingOperationCompanies()
    if (companies.length === 0) {
      return []
    }

    const result: string[] = []
    for (const company of companies) {
      if (company.cityCount === 0) continue
      const isVisible = visibility[company.slug]
      if (isVisible) {
        result.push(company.slug)
      }
    }

    return result
  })

  const ridehailingOperationsLayerFilter = $derived(
    (): maplibregl.FilterSpecification => {
      const activeSlugs = activeRidehailingOperationSlugs()
      if (activeSlugs.length === 0) {
        return ["in", "ridehailing_slug", "__no_visible_ridehailing__"]
      }

      return ["in", "ridehailing_slug", ...activeSlugs]
    },
  )

  const ridehailingFillColorExpression: () => maplibregl.DataDrivenPropertyValueSpecification<string> =
    $derived(() => {
      const entries = Array.from(ridehailingColorsBySlug().entries())
      if (entries.length === 0) {
        return "#4b5563"
      }

      return [
        "match",
        ["get", "ridehailing_slug"],
        ...entries.flatMap(([slug, color]) => [slug, color.fill]),
        "#4b5563",
      ] as unknown as maplibregl.ExpressionSpecification
    })

  const ridehailingOutlineColorExpression: () => maplibregl.DataDrivenPropertyValueSpecification<string> =
    $derived(() => {
      const entries = Array.from(ridehailingColorsBySlug().entries())
      if (entries.length === 0) {
        return "#374151"
      }

      return [
        "match",
        ["get", "ridehailing_slug"],
        ...entries.flatMap(([slug, color]) => [slug, color.outline]),
        "#374151",
      ] as unknown as maplibregl.ExpressionSpecification
    })

  const ridehailingOperationsSummary = $derived(() => {
    const counts = ridehailingCountryCounts()
    if (counts.size === 0) {
      return ""
    }

    const activeSlugs = activeRidehailingOperationSlugs()
    if (activeSlugs.length === 0) {
      return ""
    }

    const entries = activeSlugs
      .map((slug) => {
        const count = counts.get(slug)
        if (!count) {
          return null
        }

        const companyName =
          ridehailings.find((company) => company.slug === slug)?.name ?? slug
        return `${companyName}: ${count} ${count === 1 ? "country" : "countries"}`
      })
      .filter((value): value is string => Boolean(value))

    if (entries.length === 0) {
      return ""
    }

    return entries.join(", ")
  })

  const ridehailingCityOperationsDeckData = $derived(
    (): RidehailingCityOperationDeckDatum[] => {
      if (!isRidehailingOperationsEnabled) {
        return []
      }

      const activeSlugs = new Set(activeRidehailingCityOperationSlugs())
      if (activeSlugs.size === 0) {
        return []
      }

      const colors = ridehailingColorsBySlug()
      const data: RidehailingCityOperationDeckDatum[] = []

      for (const operation of ridehailingCityOperations) {
        if (!activeSlugs.has(operation.ridehailing_slug)) continue
        if (operation.longitude == null || operation.latitude == null) continue

        const colorHex =
          colors.get(operation.ridehailing_slug)?.fill ?? "#4b5563"
        const [r, g, b] = hexToRgb(colorHex)
        const elevation = computeCityElevation(operation.population)

        data.push({
          ridehailing_slug: operation.ridehailing_slug,
          city_slug: operation.city_slug,
          city_name: operation.city_name,
          longitude: operation.longitude,
          latitude: operation.latitude,
          elevation,
          fillColor: [r, g, b, 220],
        })
      }

      return data
    },
  )

  const ridehailingCityOperationsDeckLayers = $derived(() => {
    const data = ridehailingCityOperationsDeckData()
    if (data.length === 0) {
      return []
    }

    const columns = new ColumnLayer<RidehailingCityOperationDeckDatum>({
      id: "ridehailings-city-operations-columns",
      data,
      coordinateSystem: COORDINATE_SYSTEM.LNGLAT,
      pickable: false,
      diskResolution: 12,
      radius: CITY_COLUMN_RADIUS_METERS,
      extruded: true,
      elevationScale: 1,
      getPosition: (d) => [d.longitude, d.latitude],
      getFillColor: (d) => d.fillColor,
      getElevation: (d) => d.elevation,
    })

    const labels = new TextLayer<RidehailingCityOperationDeckDatum>({
      id: "ridehailings-city-operations-labels",
      data,
      coordinateSystem: COORDINATE_SYSTEM.LNGLAT,
      pickable: false,
      billboard: true,
      sizeUnits: "pixels",
      getPosition: (d) => [
        d.longitude,
        d.latitude,
        d.elevation + CITY_LABEL_VERTICAL_OFFSET,
      ],
      getText: (d) => d.city_name,
      getColor: [32, 32, 32, 230],
      getSize: 14,
      fontWeight: "600",
      background: true,
      backgroundPadding: [4, 2],
      getBackgroundColor: [255, 255, 255, 220],
    })

    return [columns, labels]
  })

  $effect(() => {
    const companies = ridehailingOperationCompanies()
    const currentVisibility = ridehailingOperationVisibilityBySlug
    const nextVisibility: Record<string, boolean> = {}
    let changed = false

    for (const company of companies) {
      const existing = currentVisibility[company.slug]
      nextVisibility[company.slug] = existing ?? true
      if (existing === undefined) {
        changed = true
      }
    }

    for (const slug in currentVisibility) {
      if (!(slug in nextVisibility)) {
        changed = true
        break
      }
    }

    if (
      changed ||
      Object.keys(currentVisibility).length !==
        Object.keys(nextVisibility).length
    ) {
      ridehailingOperationVisibilityBySlug = nextVisibility
    }
  })

  $effect(() => {
    const companies = ridehailingOperationCompanies()
    const currentVisibility = ridehailingCityVisibilityBySlug
    const nextVisibility: Record<string, boolean> = {}
    let changed = false

    for (const company of companies) {
      const existing = currentVisibility[company.slug]
      nextVisibility[company.slug] = existing ?? false
      if (existing === undefined) {
        changed = true
      }
    }

    for (const slug in currentVisibility) {
      if (!(slug in nextVisibility)) {
        changed = true
        break
      }
    }

    if (
      changed ||
      Object.keys(currentVisibility).length !==
        Object.keys(nextVisibility).length
    ) {
      ridehailingCityVisibilityBySlug = nextVisibility
    }
  })

  let hasSetGlobeProjection = false
  const failedRobotaxiImages = new Set<string>()
  const pendingRobotaxiImages = new Set<string>()
  const failedRidehailingImages = new Set<string>()
  const pendingRidehailingImages = new Set<string>()

  const ensureGlobeProjection = (m: maplibregl.Map) => {
    if (!hasSetGlobeProjection) {
      m.setProjection({ type: "globe" })
      hasSetGlobeProjection = true
    }
  }

  const focusMapOnRobotaxis = (
    m: maplibregl.Map,
    companies: Robotaxi[] | null = null,
  ) => {
    const items = (companies ?? robotaxisWithCoords()).filter(
      (company) => company.longitude != null && company.latitude != null,
    )
    if (items.length === 0) return

    const bounds = new maplibregl.LngLatBounds()
    for (const company of items) {
      bounds.extend([Number(company.longitude), Number(company.latitude)])
    }

    if (!bounds.isEmpty()) {
      m.fitBounds(bounds, { padding: 180, maxZoom: 6 })
    }
  }

  const focusMapOnRidehailings = (
    m: maplibregl.Map,
    companies: Ridehailing[] | null = null,
  ) => {
    const items = (companies ?? ridehailingsWithCoords()).filter(
      (company) => company.longitude != null && company.latitude != null,
    )
    if (items.length === 0) return

    const bounds = new maplibregl.LngLatBounds()
    for (const company of items) {
      bounds.extend([Number(company.longitude), Number(company.latitude)])
    }

    if (!bounds.isEmpty()) {
      m.fitBounds(bounds, { padding: 360, maxZoom: 6 })
    }
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
      m.fitBounds(bounds, { padding: 180, maxZoom: 6 })
    }
  }

  const ensureRidehailingOperationsLayerOrder = (m: maplibregl.Map) => {
    const fillId = "ridehailings-operations-fill"
    const outlineId = "ridehailings-operations-outline"

    if (!m.getLayer(fillId) || !m.getLayer(outlineId)) {
      return
    }

    const beforeLayerCandidates = [
      "ridehailings-circles",
      "ridehailings-logos",
      "robotaxis-circles",
      "robotaxis-logos",
      "universities-pins",
      "universities-labels",
    ]

    const beforeId = beforeLayerCandidates.find((layerId) =>
      m.getLayer(layerId),
    )
    if (!beforeId) {
      return
    }

    m.moveLayer(fillId, beforeId)
    m.moveLayer(outlineId, beforeId)
  }

  const loadRobotaxiImage = async (
    m: maplibregl.Map,
    imageName: string,
    logoUrl: string,
  ) => {
    if (m.hasImage(imageName) || failedRobotaxiImages.has(imageName)) {
      return
    }

    if (pendingRobotaxiImages.has(imageName)) {
      return
    }

    pendingRobotaxiImages.add(imageName)
    try {
      const response = await m.loadImage(logoUrl)
      if (!m.hasImage(imageName)) {
        m.addImage(imageName, response.data)
      }
    } catch (error) {
      failedRobotaxiImages.add(imageName)
      const message =
        error instanceof Error
          ? error.message
          : typeof error === "string"
            ? error
            : "Unknown error"
      console.warn(`Failed to load robotaxi logo for ${imageName}:`, message)
    } finally {
      pendingRobotaxiImages.delete(imageName)
    }
  }

  const loadRobotaxiImages = async (m: maplibregl.Map) => {
    const entries = robotaxiLogoMap()
    if (entries.size === 0) return

    const tasks: Promise<void>[] = []

    for (const [imageName, logoUrl] of entries.entries()) {
      tasks.push(loadRobotaxiImage(m, imageName, logoUrl))
    }

    if (tasks.length === 0) {
      return
    }

    await Promise.allSettled(tasks)
    m.triggerRepaint()
  }

  const loadRidehailingImage = async (
    m: maplibregl.Map,
    imageName: string,
    logoUrl: string,
  ) => {
    if (m.hasImage(imageName) || failedRidehailingImages.has(imageName)) {
      return
    }

    if (pendingRidehailingImages.has(imageName)) {
      return
    }

    pendingRidehailingImages.add(imageName)
    try {
      const response = await m.loadImage(logoUrl)
      if (!m.hasImage(imageName)) {
        m.addImage(imageName, response.data)
      }
    } catch (error) {
      failedRidehailingImages.add(imageName)
      const message =
        error instanceof Error
          ? error.message
          : typeof error === "string"
            ? error
            : "Unknown error"
      console.warn(`Failed to load ridehailing logo for ${imageName}:`, message)
    } finally {
      pendingRidehailingImages.delete(imageName)
    }
  }

  const loadRidehailingImages = async (m: maplibregl.Map) => {
    const entries = ridehailingLogoMap()
    if (entries.size === 0) return

    const tasks: Promise<void>[] = []
    for (const [imageName, logoUrl] of entries.entries()) {
      tasks.push(loadRidehailingImage(m, imageName, logoUrl))
    }

    if (tasks.length > 0) {
      await Promise.allSettled(tasks)
    }
  }

  const handleRidehailingOperationVisibilityToggle = (
    slug: string,
    checked: boolean,
  ) => {
    ridehailingOperationVisibilityBySlug = {
      ...ridehailingOperationVisibilityBySlug,
      [slug]: checked,
    }
  }

  const handleRidehailingCityVisibilityToggle = (
    slug: string,
    checked: boolean,
  ) => {
    ridehailingCityVisibilityBySlug = {
      ...ridehailingCityVisibilityBySlug,
      [slug]: checked,
    }
  }

  const handleRidehailingStyleImageMissing = (
    event: maplibregl.MapStyleImageMissingEvent,
  ) => {
    const mapInstance = map
    if (!mapInstance) return

    const imageName = event.id
    if (!imageName.startsWith("ridehailing-")) {
      return
    }

    const logoUrl = ridehailingLogoMap().get(imageName)
    if (!logoUrl) {
      return
    }

    void loadRidehailingImage(mapInstance, imageName, logoUrl)
  }

  const loadRobotaxis = async () => {
    if (isRobotaxisLoading) return

    isRobotaxisLoading = true
    robotaxisError = null

    try {
      const response = await fetch("/api/robotaxis")
      if (!response.ok) {
        throw new Error("Failed to fetch robotaxis")
      }

      const payload = (await response.json()) as {
        robotaxis: Robotaxi[]
      }

      const records = payload.robotaxis ?? []
      robotaxis = records
      hasFetchedRobotaxis = true

      const mapInstance = map
      if (mapInstance && isRobotaxisEnabled) {
        const itemsWithCoords = records.filter(
          (record) => record.longitude != null && record.latitude != null,
        )
        if (itemsWithCoords.length > 0) {
          focusMapOnRobotaxis(mapInstance, itemsWithCoords)
        }
        await loadRobotaxiImages(mapInstance)
      } else if (mapInstance) {
        await loadRobotaxiImages(mapInstance)
      }
    } catch (error) {
      const message =
        error instanceof Error ? error.message : "Unexpected error occurred"
      robotaxisError = message
      hasFetchedRobotaxis = false
    } finally {
      isRobotaxisLoading = false
    }
  }

  const loadRidehailings = async () => {
    if (isRidehailingsLoading) return

    isRidehailingsLoading = true
    ridehailingsError = null

    try {
      const response = await fetch("/api/ridehailings")
      if (!response.ok) {
        throw new Error("Failed to fetch ridehailings")
      }

      const payload = (await response.json()) as {
        ridehailings: Ridehailing[]
      }

      const records = payload.ridehailings ?? []
      ridehailings = records
      hasFetchedRidehailings = true

      const mapInstance = map
      if (mapInstance && isRidehailingsEnabled) {
        const itemsWithCoords = records.filter(
          (record) => record.longitude != null && record.latitude != null,
        )
        if (itemsWithCoords.length > 0) {
          focusMapOnRidehailings(mapInstance, itemsWithCoords)
        }
      }
    } catch (error) {
      const message =
        error instanceof Error ? error.message : "Unexpected error occurred"
      ridehailingsError = message
      hasFetchedRidehailings = false
    } finally {
      isRidehailingsLoading = false
    }
  }

  const loadRidehailingOperations = async () => {
    if (isRidehailingOperationsLoading) return

    isRidehailingOperationsLoading = true
    ridehailingOperationsError = null

    try {
      const response = await fetch("/api/ridehailings/operations")
      if (!response.ok) {
        throw new Error("Failed to fetch ridehailing operations")
      }

      const payload = (await response.json()) as {
        countryOperations: RidehailingCountryOperation[]
        cityOperations?: RidehailingCityOperationPayload[]
      }

      ridehailingCountryOperations = payload.countryOperations ?? []
      const cityOps = payload.cityOperations ?? []
      ridehailingCityOperations = cityOps.map((operation) => ({
        ridehailing_slug: operation.ridehailing_slug,
        city_slug: operation.city_slug,
        city_name: operation.city_name,
        country_slug: operation.country_slug ?? null,
        latitude:
          typeof operation.latitude === "number" &&
          Number.isFinite(operation.latitude)
            ? operation.latitude
            : null,
        longitude:
          typeof operation.longitude === "number" &&
          Number.isFinite(operation.longitude)
            ? operation.longitude
            : null,
        population:
          typeof operation.population === "number" &&
          Number.isFinite(operation.population)
            ? operation.population
            : null,
      }))
      hasFetchedRidehailingOperations = true

      const mapInstance = map
      if (mapInstance && isRidehailingOperationsEnabled) {
        await tick()
        ensureRidehailingOperationsLayerOrder(mapInstance)
      }
    } catch (error) {
      const message =
        error instanceof Error ? error.message : "Unexpected error occurred"
      ridehailingOperationsError = message
      hasFetchedRidehailingOperations = false
    } finally {
      isRidehailingOperationsLoading = false
    }
  }

  const loadCountryBoundaries = async () => {
    if (countriesGeoJson || isCountryBoundariesLoading) return

    isCountryBoundariesLoading = true
    countryBoundariesError = null

    try {
      const response = await fetch("/data/countries-simplified.geojson")
      if (!response.ok) {
        throw new Error("Failed to fetch country boundaries")
      }

      const payload = (await response.json()) as CountryFeatureCollection
      countriesGeoJson = payload
    } catch (error) {
      const message =
        error instanceof Error ? error.message : "Unexpected error occurred"
      countryBoundariesError = message
    } finally {
      isCountryBoundariesLoading = false
    }
  }

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

      const mapInstance = map
      if (mapInstance && isUniversitiesEnabled) {
        focusMapOnUniversities(mapInstance)
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

  const handleRobotaxisToggle = async (checked: boolean) => {
    isRobotaxisEnabled = checked

    if (!checked) {
      return
    }

    if (!hasFetchedRobotaxis) {
      await loadRobotaxis()
    }

    const mapInstance = map
    if (mapInstance) {
      await loadRobotaxiImages(mapInstance)
    }
  }

  const handleRidehailingsToggle = async (checked: boolean) => {
    isRidehailingsEnabled = checked

    if (!checked) {
      isRidehailingOperationsEnabled = false
    }

    if (checked && !hasFetchedRidehailings) {
      await loadRidehailings()
    }
  }

  const handleRidehailingOperationsToggle = async (checked: boolean) => {
    if (!isRidehailingsEnabled) {
      isRidehailingOperationsEnabled = false
      return
    }

    isRidehailingOperationsEnabled = checked

    if (!checked) {
      return
    }

    const tasks: Promise<unknown>[] = []

    if (!hasFetchedRidehailings) {
      tasks.push(loadRidehailings())
    }

    if (!hasFetchedRidehailingOperations) {
      tasks.push(loadRidehailingOperations())
    }

    if (!countriesGeoJson) {
      tasks.push(loadCountryBoundaries())
    }

    if (tasks.length > 0) {
      await Promise.allSettled(tasks)
    }

    const mapInstance = map
    if (mapInstance) {
      await tick()
      ensureRidehailingOperationsLayerOrder(mapInstance)
    }
  }

  const handleUniversitiesToggle = async (checked: boolean) => {
    isUniversitiesEnabled = checked

    if (checked && !hasFetchedUniversities) {
      await loadUniversities()
    }
  }

  const handleRetryRobotaxis = async () => {
    hasFetchedRobotaxis = false
    if (isRobotaxisEnabled) {
      await loadRobotaxis()
    }
  }

  const handleRetryRidehailings = async () => {
    hasFetchedRidehailings = false
    if (isRidehailingsEnabled) {
      await loadRidehailings()
    }
  }

  const handleRetryRidehailingOperations = async () => {
    hasFetchedRidehailingOperations = false
    await loadRidehailingOperations()
    if (!countriesGeoJson) {
      await loadCountryBoundaries()
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

  const handleMouseEnter = () => {
    const mapInstance = map
    if (!mapInstance) return
    mapInstance.getCanvas().style.cursor = "pointer"
  }

  const handleMouseLeave = () => {
    const mapInstance = map
    if (!mapInstance) return
    mapInstance.getCanvas().style.cursor = ""
  }

  const handleRobotaxiClick = (event: maplibregl.MapLayerMouseEvent) => {
    const mapInstance = map
    if (!mapInstance) return

    const feature = event.features?.[0]
    if (!feature) return

    const props = feature.properties ?? {}
    const geometry = feature.geometry as {
      type: string
      coordinates: [number, number]
    }

    const coordinates = geometry.coordinates
    const rawName = props.name ? String(props.name) : "Robotaxi"
    const rawAddress = props.address ? String(props.address) : ""
    const rawWebsite = props.website ? String(props.website) : ""

    const name = escapeHtml(rawName)
    const address = rawAddress ? escapeHtml(rawAddress) : ""
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

    if (address) {
      details.push(`
        <div class="popup-field">
          <span class="popup-label">📍 Address</span>
          <span class="popup-value">${address}</span>
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
      .addTo(mapInstance)
  }

  const handleRidehailingClick = (event: maplibregl.MapLayerMouseEvent) => {
    const mapInstance = map
    if (!mapInstance) return

    const feature = event.features?.[0]
    if (!feature) return

    const props = feature.properties ?? {}
    const geometry = feature.geometry as {
      type: string
      coordinates: [number, number]
    }

    const coordinates = geometry.coordinates
    const rawName = props.name ? String(props.name) : "Ridehailing"
    const rawAddress = props.address ? String(props.address) : ""
    const rawWebsite = props.website ? String(props.website) : ""

    const name = escapeHtml(rawName)
    const address = rawAddress ? escapeHtml(rawAddress) : ""
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

    if (address) {
      details.push(`
        <div class="popup-field">
          <span class="popup-label">📍 Address</span>
          <span class="popup-value">${address}</span>
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
      .addTo(mapInstance)
  }

  const handleUniversityClick = (event: maplibregl.MapLayerMouseEvent) => {
    const mapInstance = map
    if (!mapInstance) return

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
      .addTo(mapInstance)
  }

  onMount(() => {
    if (isRobotaxisEnabled && !hasFetchedRobotaxis) {
      void loadRobotaxis()
    }

    const ridehailingTasks: Promise<unknown>[] = []

    if (isRidehailingsEnabled && !hasFetchedRidehailings) {
      ridehailingTasks.push(loadRidehailings())
    }

    if (isRidehailingOperationsEnabled) {
      if (!hasFetchedRidehailings && ridehailingTasks.length === 0) {
        ridehailingTasks.push(loadRidehailings())
      }

      if (!hasFetchedRidehailingOperations) {
        ridehailingTasks.push(loadRidehailingOperations())
      }

      if (!countriesGeoJson) {
        ridehailingTasks.push(loadCountryBoundaries())
      }
    }

    if (ridehailingTasks.length > 0) {
      void Promise.allSettled(ridehailingTasks)
    }

    const mapInstance = map
    if (!mapInstance) return

    const reattachHandlers = () => {
      mapInstance.off("styledata", reattachHandlers)

      for (const layerId of robotaxiLayerIds) {
        mapInstance.off("click", layerId, handleRobotaxiClick)
        mapInstance.on("click", layerId, handleRobotaxiClick)
      }

      mapInstance.off("click", "universities-pins", handleUniversityClick)
      mapInstance.on("click", "universities-pins", handleUniversityClick)

      mapInstance.on("styledata", reattachHandlers)
    }

    mapInstance.on("styledata", reattachHandlers)

    return () => {
      mapInstance.off("styledata", reattachHandlers)
    }
  })

  const robotaxiLayerIds = ["robotaxis-logos", "robotaxis-circles"] as const
  const ridehailingLayerIds = [
    "ridehailings-logos",
    "ridehailings-circles",
  ] as const

  $effect(() => {
    const mapInstance = map
    const robotaxiCount = robotaxisWithCoords().length
    const enabled = isRobotaxisEnabled

    if (!mapInstance) return

    let handlersAttached = false

    const attachHandlers = () => {
      if (handlersAttached) return
      const layersReady = robotaxiLayerIds.every((layerId) =>
        Boolean(mapInstance.getLayer(layerId)),
      )
      if (!layersReady) return

      for (const layerId of robotaxiLayerIds) {
        mapInstance.on("click", layerId, handleRobotaxiClick)
        mapInstance.on("mouseenter", layerId, handleMouseEnter)
        mapInstance.on("mouseleave", layerId, handleMouseLeave)
      }
      handlersAttached = true
    }

    const detachHandlers = () => {
      if (!handlersAttached) return

      for (const layerId of robotaxiLayerIds) {
        mapInstance.off("click", layerId, handleRobotaxiClick)
        mapInstance.off("mouseenter", layerId, handleMouseEnter)
        mapInstance.off("mouseleave", layerId, handleMouseLeave)
      }
      handlersAttached = false
    }

    const handleData = (event: maplibregl.MapDataEvent) => {
      if (
        "sourceId" in event &&
        event.sourceId === "robotaxis" &&
        "isSourceLoaded" in event &&
        event.isSourceLoaded
      ) {
        attachHandlers()
      }
    }

    const setup = () => {
      ensureGlobeProjection(mapInstance)
      if (enabled && robotaxiCount > 0) {
        focusMapOnRobotaxis(mapInstance)
      }

      mapInstance.on("data", handleData)

      const source = mapInstance.getSource("robotaxis")
      if (source && mapInstance.isSourceLoaded("robotaxis")) {
        attachHandlers()
      }
    }

    const cleanup = () => {
      mapInstance.off("data", handleData)
      detachHandlers()
    }

    if (!mapInstance.loaded()) {
      const onLoad = () => {
        setup()
      }
      mapInstance.once("load", onLoad)
      return () => {
        mapInstance.off("load", onLoad)
        cleanup()
      }
    }

    setup()

    return () => {
      cleanup()
    }
  })

  $effect(() => {
    const mapInstance = map
    const ridehailingCount = ridehailingsWithCoords().length
    const enabled = isRidehailingsEnabled

    if (!mapInstance) return

    let handlersAttached = false

    const attachHandlers = () => {
      if (handlersAttached) return
      const layersReady = ridehailingLayerIds.every((layerId) =>
        Boolean(mapInstance.getLayer(layerId)),
      )
      if (!layersReady) return

      for (const layerId of ridehailingLayerIds) {
        mapInstance.on("click", layerId, handleRidehailingClick)
        mapInstance.on("mouseenter", layerId, handleMouseEnter)
        mapInstance.on("mouseleave", layerId, handleMouseLeave)
      }
      handlersAttached = true
    }

    const detachHandlers = () => {
      if (!handlersAttached) return

      for (const layerId of ridehailingLayerIds) {
        mapInstance.off("click", layerId, handleRidehailingClick)
        mapInstance.off("mouseenter", layerId, handleMouseEnter)
        mapInstance.off("mouseleave", layerId, handleMouseLeave)
      }
      handlersAttached = false
    }

    const handleData = (event: maplibregl.MapDataEvent) => {
      if (
        "sourceId" in event &&
        event.sourceId === "ridehailings" &&
        "isSourceLoaded" in event &&
        event.isSourceLoaded
      ) {
        attachHandlers()
      }
    }

    const setup = () => {
      ensureGlobeProjection(mapInstance)
      if (enabled && ridehailingCount > 0) {
        focusMapOnRidehailings(mapInstance)
      }
      void loadRidehailingImages(mapInstance)

      mapInstance.on("styleimagemissing", handleRidehailingStyleImageMissing)
      mapInstance.on("data", handleData)

      const source = mapInstance.getSource("ridehailings")
      if (source && mapInstance.isSourceLoaded("ridehailings")) {
        attachHandlers()
      }
    }

    const cleanup = () => {
      mapInstance.off("styleimagemissing", handleRidehailingStyleImageMissing)
      mapInstance.off("data", handleData)
      detachHandlers()
    }

    if (!mapInstance.loaded()) {
      const onLoad = () => {
        setup()
      }
      mapInstance.once("load", onLoad)
      return () => {
        mapInstance.off("load", onLoad)
        cleanup()
      }
    }

    setup()

    return () => {
      cleanup()
    }
  })

  $effect(() => {
    const mapInstance = map
    const universityCount = universitiesWithCoords().length
    const enabled = isUniversitiesEnabled

    if (!mapInstance) return

    let handlersAttached = false

    const attachHandlers = () => {
      if (handlersAttached) return
      const layerExists = Boolean(mapInstance.getLayer("universities-pins"))
      if (!layerExists) return

      mapInstance.on("click", "universities-pins", handleUniversityClick)
      mapInstance.on("mouseenter", "universities-pins", handleMouseEnter)
      mapInstance.on("mouseleave", "universities-pins", handleMouseLeave)
      handlersAttached = true
    }

    const detachHandlers = () => {
      if (!handlersAttached) return

      mapInstance.off("click", "universities-pins", handleUniversityClick)
      mapInstance.off("mouseenter", "universities-pins", handleMouseEnter)
      mapInstance.off("mouseleave", "universities-pins", handleMouseLeave)
      handlersAttached = false
    }

    const handleData = (event: maplibregl.MapDataEvent) => {
      if (
        "sourceId" in event &&
        event.sourceId === "universities" &&
        "isSourceLoaded" in event &&
        event.isSourceLoaded
      ) {
        attachHandlers()
      }
    }

    const setup = () => {
      ensureGlobeProjection(mapInstance)
      if (enabled && universityCount > 0) {
        focusMapOnUniversities(mapInstance)
      }

      mapInstance.on("data", handleData)

      const source = mapInstance.getSource("universities")
      if (source && mapInstance.isSourceLoaded("universities")) {
        attachHandlers()
      }
    }

    const cleanup = () => {
      mapInstance.off("data", handleData)
      detachHandlers()
    }

    if (!mapInstance.loaded()) {
      const onLoad = () => {
        setup()
      }
      mapInstance.once("load", onLoad)
      return () => {
        mapInstance.off("load", onLoad)
        cleanup()
      }
    }

    setup()

    return () => {
      cleanup()
    }
  })
</script>

<div class="map-page">
  <MapLibre
    bind:map
    class="h-full w-full"
    style="https://basemaps.cartocdn.com/gl/positron-gl-style/style.json"
    zoom={2}
  >
    <GlobeControl />
    <DeckGLOverlay layers={ridehailingCityOperationsDeckLayers()} />

    {#if isRidehailingOperationsEnabled && ridehailingOperationsGeoJson().features.length > 0}
      <GeoJSONSource
        id="ridehailings-operations"
        data={ridehailingOperationsGeoJson()}
      >
        <FillLayer
          id="ridehailings-operations-fill"
          filter={ridehailingOperationsLayerFilter()}
          paint={{
            "fill-color": ridehailingFillColorExpression(),
            "fill-opacity": 0.22,
          }}
        />
        <LineLayer
          id="ridehailings-operations-outline"
          filter={ridehailingOperationsLayerFilter()}
          paint={{
            "line-color": ridehailingOutlineColorExpression(),
            "line-width": 1,
            "line-opacity": 0.6,
          }}
        />
      </GeoJSONSource>
    {/if}

    <GeoJSONSource id="ridehailings" data={ridehailingGeoJson()}>
      <SymbolLayer
        id="ridehailings-logos"
        filter={["all", ["!=", ["get", "imageName"], null]]}
        layout={{
          "icon-image": ["get", "imageName"],
          "icon-size": 0.28,
          "icon-allow-overlap": true,
          "icon-ignore-placement": true,
        }}
      />
      <CircleLayer
        id="ridehailings-circles"
        filter={["all", ["==", ["get", "imageName"], null]]}
        paint={{
          "circle-radius": 6,
          "circle-color": "#0ea5e9",
          "circle-opacity": 0.9,
          "circle-stroke-width": 1.5,
          "circle-stroke-color": "#ffffff",
        }}
      />
    </GeoJSONSource>

    <GeoJSONSource id="robotaxis" data={robotaxiGeoJson()}>
      <SymbolLayer
        id="robotaxis-logos"
        filter={["all", ["!=", ["get", "imageName"], null]]}
        layout={{
          "icon-image": ["get", "imageName"],
          "icon-size": 0.28,
          "icon-allow-overlap": true,
          "icon-ignore-placement": true,
        }}
      />

      <CircleLayer
        id="robotaxis-circles"
        filter={["all", ["==", ["get", "imageName"], null]]}
        paint={{
          "circle-radius": 6,
          "circle-color": "#2563eb",
          "circle-opacity": 0.9,
          "circle-stroke-width": 1.5,
          "circle-stroke-color": "#ffffff",
        }}
      />
    </GeoJSONSource>

    <GeoJSONSource id="universities" data={universitiesGeoJson()}>
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
            checked={isRobotaxisEnabled}
            onchange={(event) =>
              handleRobotaxisToggle(
                (event.currentTarget as HTMLInputElement).checked,
              )}
          />
          <span class="menu-label">Robotaxi companies</span>
        </label>

        {#if isRobotaxisLoading}
          <p class="menu-status">Loading robotaxis…</p>
        {:else if robotaxisError}
          <p class="menu-status error">Failed to load: {robotaxisError}</p>
          <button
            class="retry-button"
            type="button"
            onclick={handleRetryRobotaxis}
          >
            Try again
          </button>
        {:else if hasFetchedRobotaxis && robotaxisWithCoords().length > 0}
          <p class="menu-status">
            Showing {robotaxisWithCoords().length} robotaxi companies
          </p>
        {/if}

        <label class="menu-item">
          <input
            type="checkbox"
            checked={isRidehailingsEnabled}
            onchange={(event) =>
              handleRidehailingsToggle(
                (event.currentTarget as HTMLInputElement).checked,
              )}
          />
          <span class="menu-label">Ridehailing companies</span>
        </label>

        {#if isRidehailingsLoading}
          <p class="menu-status">Loading ridehailings…</p>
        {:else if ridehailingsError}
          <p class="menu-status error">Failed to load: {ridehailingsError}</p>
          <button
            class="retry-button"
            type="button"
            onclick={handleRetryRidehailings}
          >
            Try again
          </button>
        {:else if hasFetchedRidehailings}
          <!-- Ridehailing data loaded; no status message shown -->
        {/if}

        {#if isRidehailingsEnabled}
          <div class="menu-group menu-subgroup">
            <label class="menu-item menu-subitem">
              <input
                type="checkbox"
                checked={isRidehailingOperationsEnabled}
                onchange={(event) =>
                  handleRidehailingOperationsToggle(
                    (event.currentTarget as HTMLInputElement).checked,
                  )}
              />
              <span class="menu-label">Operations</span>
            </label>

            {#if isRidehailingOperationsLoading || isCountryBoundariesLoading}
              <p class="menu-status menu-substatus">Loading operations…</p>
            {:else if ridehailingOperationsError || countryBoundariesError}
              <p class="menu-status error menu-substatus">
                {#if ridehailingOperationsError}
                  Failed to load operations: {ridehailingOperationsError}
                {/if}
                {#if countryBoundariesError}
                  {#if ridehailingOperationsError}
                    <br />
                  {/if}
                  Failed to load country boundaries: {countryBoundariesError}
                {/if}
              </p>
              <button
                class="retry-button menu-substatus"
                type="button"
                onclick={handleRetryRidehailingOperations}
              >
                Try again
              </button>
            {:else if isRidehailingOperationsEnabled && hasFetchedRidehailingOperations}
              {#if ridehailingOperationsGeoJson().features.length === 0}
                <p class="menu-status menu-substatus">No operations data yet.</p>
              {:else}
                {#if ridehailingOperationCompanies().length > 0}
                  <div class="operations-checkboxes">
                    {#each ridehailingOperationCompanies() as company}
                      <div class="operations-company">
                        <label class="menu-item menu-subitem operations-company-row">
                          <input
                            type="checkbox"
                            checked={ridehailingOperationVisibilityBySlug[
                              company.slug
                            ] ?? true}
                            onchange={(event) =>
                              handleRidehailingOperationVisibilityToggle(
                                company.slug,
                                (event.currentTarget as HTMLInputElement).checked,
                              )}
                          />
                          <span class="menu-label">{company.name}</span>
                          <span class="menu-meta">
                            {company.countryCount}{" "}
                            {company.countryCount === 1 ? "country" : "countries"}
                          </span>
                        </label>
                        {#if company.cityCount > 0}
                          <label class="menu-item menu-subitem operations-company-row city">
                            <input
                              type="checkbox"
                              checked={ridehailingCityVisibilityBySlug[
                                company.slug
                              ] ?? false}
                              onchange={(event) =>
                                handleRidehailingCityVisibilityToggle(
                                  company.slug,
                                  (event.currentTarget as HTMLInputElement)
                                    .checked,
                                )}
                            />
                            <span class="menu-label">Cities</span>
                            <span class="menu-meta">
                              {company.cityCount}{" "}
                              {company.cityCount === 1 ? "city" : "cities"}
                            </span>
                          </label>
                        {/if}
                      </div>
                    {/each}
                  </div>
                {/if}
              {/if}
            {/if}
          </div>
        {/if}

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

  {#if isRobotaxisEnabled && hasFetchedRobotaxis && !isRobotaxisLoading && robotaxisWithCoords().length === 0}
    <div class="empty-state">No robotaxi companies available yet.</div>
  {/if}

  {#if isRidehailingsEnabled && hasFetchedRidehailings && !isRidehailingsLoading && ridehailingsWithCoords().length === 0}
    <div class="empty-state">No ridehailing companies available yet.</div>
  {/if}

  {#if isUniversitiesEnabled && hasFetchedUniversities && !isUniversitiesLoading && universitiesWithCoords().length === 0}
    <div class="empty-state">No universities available yet.</div>
  {/if}

  <div class="contribute-wrapper">
    <a
      class="contribute-button"
      href="https://github.com/rinat-enikeev/robotaxi/tree/main/data"
      target="_blank"
      rel="noopener noreferrer"
    >
      Contribute on GitHub
    </a>
  </div>
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

  .menu-subitem {
    padding-left: 1.5rem;
  }

  .menu-subitem input {
    margin-left: -1.5rem;
  }

  .menu-group {
    display: flex;
    flex-direction: column;
    gap: 0.35rem;
  }

  .menu-subgroup {
    margin-left: 1.5rem;
  }

  .menu-subgroup .menu-substatus {
    margin-left: 0;
  }

  .menu-substatus {
    margin-left: 1.5rem;
  }

  .operations-checkboxes {
    margin-top: 0.5rem;
    display: flex;
    flex-direction: column;
    gap: 0.35rem;
  }

  .operations-company {
    display: flex;
    flex-direction: column;
    gap: 0.2rem;
  }

  .operations-company + .operations-company {
    margin-top: 0.25rem;
  }

  .operations-company-row.city {
    padding-left: 2.5rem;
  }

  .operations-company-row.city input {
    margin-left: 0;
  }

  .menu-label {
    flex: 1;
  }

  .menu-meta {
    margin-left: auto;
    font-size: 0.75rem;
    font-weight: 400;
    color: #6b7280;
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

  .contribute-wrapper {
    position: absolute;
    left: 50%;
    bottom: 1.5rem;
    transform: translateX(-50%);
    z-index: 30;
  }

  .contribute-button {
    display: inline-flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.75rem 1.5rem;
    border-radius: 9999px;
    background: rgba(255, 255, 255, 0.9);
    border: 1px solid rgba(17, 24, 39, 0.12);
    box-shadow: 0 12px 28px rgba(15, 23, 42, 0.18);
    color: #111827;
    font-weight: 600;
    text-decoration: none;
    transition:
      transform 150ms ease,
      box-shadow 150ms ease;
  }

  .contribute-button:hover {
    transform: translateY(-2px);
    box-shadow: 0 18px 32px rgba(15, 23, 42, 0.22);
  }

  .contribute-button:focus-visible {
    outline: 2px solid #2563eb;
    outline-offset: 2px;
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
