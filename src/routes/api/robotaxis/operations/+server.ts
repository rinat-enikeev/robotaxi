import { json } from "@sveltejs/kit"
import type { RequestHandler } from "./$types"

export const GET: RequestHandler = async ({ locals }) => {
  const { supabase } = locals

  if (!supabase) {
    return json({ error: "Supabase client is unavailable" }, { status: 500 })
  }

  const { data: cityOperationsRaw, error: cityOperationsError } = await supabase
    .from("robotaxi_city_operations")
    .select("robotaxi_slug, city_slug")
    .order("robotaxi_slug", { ascending: true })

  if (cityOperationsError) {
    console.error(
      "Error fetching robotaxi city operations:",
      cityOperationsError,
    )
    return json({ error: cityOperationsError.message }, { status: 500 })
  }

  const chunkArray = <T>(values: T[], size: number): T[][] => {
    if (size <= 0) return [values]
    const chunks: T[][] = []
    for (let index = 0; index < values.length; index += size) {
      chunks.push(values.slice(index, index + size))
    }
    return chunks
  }

  const citySlugSet = new Set<string>()
  for (const operation of cityOperationsRaw ?? []) {
    citySlugSet.add(operation.city_slug)
  }

  let cities: {
    slug: string
    city: string
    latitude: number | string | null
    longitude: number | string | null
    country_slug: string | null
    population: number | string | null
  }[] = []

  if (citySlugSet.size > 0) {
    const citySlugs = Array.from(citySlugSet)
    const chunks = chunkArray(citySlugs, 100)
    const cityResults: typeof cities = []

    for (const chunk of chunks) {
      const { data: chunkData, error: chunkError } = await supabase
        .from("cities")
        .select("slug, city, latitude, longitude, country_slug, population")
        .in("slug", chunk)

      if (chunkError) {
        console.error("Error fetching city metadata:", chunkError)
        return json({ error: chunkError.message }, { status: 500 })
      }

      if (chunkData) {
        cityResults.push(...chunkData)
      }
    }

    cities = cityResults
  }

  const cityLookup = new Map(cities.map((city) => [city.slug, city]))

  const cityOperations: {
    robotaxi_slug: string
    city_slug: string
    city_name: string
    country_slug: string | null
    latitude: number | null
    longitude: number | null
    population: number | null
  }[] = []

  for (const operation of cityOperationsRaw ?? []) {
    const city = cityLookup.get(operation.city_slug)
    if (!city) continue

    const latitudeValue =
      city.latitude === null || city.latitude === undefined
        ? null
        : Number(city.latitude)
    const longitudeValue =
      city.longitude === null || city.longitude === undefined
        ? null
        : Number(city.longitude)
    const populationValue =
      city.population === null || city.population === undefined
        ? null
        : Number(city.population)
    const latitude =
      typeof latitudeValue === "number" && Number.isFinite(latitudeValue)
        ? latitudeValue
        : null
    const longitude =
      typeof longitudeValue === "number" && Number.isFinite(longitudeValue)
        ? longitudeValue
        : null
    const population =
      typeof populationValue === "number" && Number.isFinite(populationValue)
        ? populationValue
        : null

    cityOperations.push({
      robotaxi_slug: operation.robotaxi_slug,
      city_slug: operation.city_slug,
      city_name: city.city,
      country_slug: city.country_slug ?? null,
      latitude,
      longitude,
      population,
    })
  }

  return json({ cityOperations })
}
