import { json } from "@sveltejs/kit"
import type { RequestHandler } from "./$types"

export const GET: RequestHandler = async ({ locals }) => {
  const { supabase } = locals

  if (!supabase) {
    return json({ error: "Supabase client is unavailable" }, { status: 500 })
  }

  const { data, error } = await supabase
    .from("factories")
    .select("*")
    .order("manufacturer", { ascending: true })
    .order("brand", { ascending: true })

  if (error) {
    console.error("Error fetching factories:", error)
    return json({ error: error.message }, { status: 500 })
  }

  return json({ factories: data ?? [] })
}
