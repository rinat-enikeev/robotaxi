prepare_seeds:
	./scripts/generate_cities_seed.sh
generate_universities_seed:
	./scripts/generate_universities_seed.sh

bootstrap: prepare_seeds generate_universities_seed
