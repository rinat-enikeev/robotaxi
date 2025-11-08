import { createReadStream, readFileSync } from 'node:fs';
import path from 'node:path';
import readline from 'node:readline';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const projectRoot = path.resolve(__dirname, '..');

const operationsPath = path.join(projectRoot, 'data', 'operations.yaml');
const citiesPath = path.join(projectRoot, 'data', 'cities.yaml');

const operationsContent = readFileSync(operationsPath, 'utf8');

const parseOperations = (content) => {
  const lines = content.split(/\r?\n/);
  const operations = [];
  let current = null;
  let mode = null;

  for (const line of lines) {
    if (!line.trim()) continue;

    if (line.startsWith('- slug:')) {
      const slug = line.slice('- slug:'.length).trim();
      current = { slug, countries: [], cities: [] };
      operations.push(current);
      mode = null;
      continue;
    }

    if (!current) continue;

    const trimmed = line.trim();

    if (trimmed === 'countries:') {
      mode = 'countries';
      continue;
    }

    if (trimmed === 'cities:') {
      mode = 'cities';
      continue;
    }

    if (trimmed.startsWith('- ')) {
      if (!mode) {
        throw new Error(`Unexpected list item without context: "${line}"`);
      }

      current[mode].push(trimmed.slice(2).trim());
    }
  }

  return operations;
};

const operations = parseOperations(operationsContent);
const operationCitySlugs = new Set(
  operations.flatMap((operation) => operation.cities)
);

const citySlugs = new Set();

await new Promise((resolve, reject) => {
  const reader = readline.createInterface({
    input: createReadStream(citiesPath, { encoding: 'utf8' }),
    crlfDelay: Infinity,
  });

  reader.on('line', (line) => {
    const trimmed = line.trim();

    if (trimmed.startsWith('- slug:')) {
      const slug = trimmed.slice('- slug:'.length).trim();
      citySlugs.add(slug);
    }
  });

  reader.on('close', resolve);
  reader.on('error', reject);
});

const missing = Array.from(operationCitySlugs).filter(
  (slug) => !citySlugs.has(slug)
);

if (missing.length > 0) {
  console.error(
    `Missing ${missing.length} city slugs from ${citiesPath}:\n` +
      missing.map((slug) => `- ${slug}`).join('\n')
  );
  process.exitCode = 1;
} else {
  console.log(
    `All ${operationCitySlugs.size} operation city slugs exist in ${citiesPath}.`
  );
}

