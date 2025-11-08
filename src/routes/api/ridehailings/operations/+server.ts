import { json } from "@sveltejs/kit"
import type { RequestHandler } from "./$types"

export const GET: RequestHandler = async ({ locals }) => {
  const { supabase } = locals

  if (!supabase) {
    return json({ error: "Supabase client is unavailable" }, { status: 500 })
  }

  const [
    { data: operations, error: operationsError },
    { data: countries, error: countriesError },
  ] = await Promise.all([
    supabase
      .from("ridehailing_country_operations")
      .select("ridehailing_slug, country_slug")
      .order("ridehailing_slug", { ascending: true }),
    supabase
      .from("countries")
      .select("slug, iso_3166_1_alpha_2, iso_3166_1_alpha_3"),
  ])

  if (operationsError) {
    console.error("Error fetching ridehailing operations:", operationsError)
    return json({ error: operationsError.message }, { status: 500 })
  }

  if (countriesError) {
    console.error("Error fetching country metadata:", countriesError)
    return json({ error: countriesError.message }, { status: 500 })
  }

  const isoLookup = new Map<
    string,
    { iso_alpha_2: string | null; iso_alpha_3: string | null }
  >()

  for (const country of countries ?? []) {
    isoLookup.set(country.slug, {
      iso_alpha_2: country.iso_3166_1_alpha_2 ?? null,
      iso_alpha_3: country.iso_3166_1_alpha_3 ?? null,
    })
  }

  const countryOperations =
    operations?.map((operation) => {
      const iso = isoLookup.get(operation.country_slug) ?? {
        iso_alpha_2: null,
        iso_alpha_3: null,
      }

      return {
        ridehailing_slug: operation.ridehailing_slug,
        country_slug: operation.country_slug,
        iso_alpha_2: iso.iso_alpha_2,
        iso_alpha_3: iso.iso_alpha_3,
      }
    }) ?? []

  return json({ countryOperations })
}
