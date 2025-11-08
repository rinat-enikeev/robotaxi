import { createReadStream } from "node:fs"
import path from "node:path"
import readline from "node:readline"
import { fileURLToPath } from "node:url"

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)
const projectRoot = path.resolve(__dirname, "..")

const citiesPath = path.join(projectRoot, "data", "cities.yaml")

const targetCountry = "switzerland"
const targetAdmin = "aargau"

const citySlugs = []

let current = null

const finalizeCurrent = () => {
  if (
    current &&
    current.country_slug === targetCountry &&
    current.admin_name &&
    current.admin_name.toLowerCase() === targetAdmin
  ) {
    citySlugs.push(current.slug)
  }
  current = null
}

const reader = readline.createInterface({
  input: createReadStream(citiesPath, { encoding: "utf8" }),
  crlfDelay: Infinity,
})

reader.on("line", (line) => {
  const trimmed = line.trim()

  if (!trimmed) {
    return
  }

  if (trimmed.startsWith("- slug:")) {
    finalizeCurrent()
    current = { slug: trimmed.slice("- slug:".length).trim() }
    return
  }

  if (!current) {
    return
  }

  const separatorIndex = trimmed.indexOf(":")
  if (separatorIndex === -1) {
    return
  }

  const key = trimmed.slice(0, separatorIndex).trim()
  const rawValue = trimmed.slice(separatorIndex + 1).trim()

  if (!rawValue) {
    return
  }

  const value = rawValue.replace(/^['"]|['"]$/g, "")

  if (key === "country_slug" || key === "admin_name") {
    current[key] = value
  }
})

reader.on("close", () => {
  finalizeCurrent()

  if (citySlugs.length === 0) {
    console.log(
      `No cities found for admin area "${targetAdmin}" in country "${targetCountry}".`,
    )
    return
  }

  console.log(
    `Found ${citySlugs.length} cities in admin area "${targetAdmin}" (${targetCountry}):`,
  )
  citySlugs.forEach((slug) => console.log(`- ${slug}`))
})

reader.on("error", (error) => {
  console.error(`Failed to read ${citiesPath}:`, error)
  process.exitCode = 1
})
