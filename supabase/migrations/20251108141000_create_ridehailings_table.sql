-- Migration: create_ridehailings_table
-- Seed data is managed via scripts/generate_ridehailings_seed.sh

CREATE TABLE public.ridehailings (
  id BIGSERIAL PRIMARY KEY,
  slug TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  website TEXT,
  city_slug TEXT NOT NULL REFERENCES public.cities(slug) ON DELETE CASCADE,
  country_slug TEXT NOT NULL REFERENCES public.countries(slug) ON DELETE CASCADE,
  latitude NUMERIC(9,6) NOT NULL,
  longitude NUMERIC(9,6) NOT NULL,
  address TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

CREATE INDEX ridehailings_city_slug_idx ON public.ridehailings (city_slug);
CREATE INDEX ridehailings_country_slug_idx ON public.ridehailings (country_slug);

CREATE TRIGGER update_ridehailings_updated_at
BEFORE UPDATE ON public.ridehailings
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();

