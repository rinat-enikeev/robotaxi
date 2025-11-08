import type { PageServerLoad } from "./$types"

export const load: PageServerLoad = async ({ locals: { supabase } }) => {
  // Fetch universities data from Supabase
  const { data: universities, error } = await supabase
    .from("universities")
    .select("*")
    .order("name", { ascending: true })

  if (error) {
    console.error("Error fetching universities:", error)
    return {
      universities: [],
      error: error.message,
    }
  }

  return {
    universities: universities || [],
  }
}
