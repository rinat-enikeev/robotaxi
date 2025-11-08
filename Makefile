generate_cities_seed:
	./scripts/generate_cities_seed.sh
generate_universities_seed:
	./scripts/generate_universities_seed.sh

generate_seed: generate_cities_seed generate_universities_seed
