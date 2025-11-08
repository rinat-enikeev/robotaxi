import { json } from "@sveltejs/kit"
import type { RequestHandler } from "./$types"

export const GET: RequestHandler = async ({ locals }) => {
  const { supabase } = locals

  if (!supabase) {
    return json({ error: "Supabase client is unavailable" }, { status: 500 })
  }

  const { data, error } = await supabase
    .from("ridehailings")
    .select("*")
    .order("name", { ascending: true })

  if (error) {
    console.error("Error fetching ridehailings:", error)
    return json({ error: error.message }, { status: 500 })
  }

  return json({ ridehailings: data ?? [] })
}
