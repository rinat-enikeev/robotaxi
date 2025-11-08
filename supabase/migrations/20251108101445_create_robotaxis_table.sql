-- Migration: create_robotaxis_table
-- Seed data is managed separately via scripts/generate_robotaxis_seed.sh

CREATE TABLE public.robotaxis (
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

CREATE INDEX robotaxis_city_slug_idx ON public.robotaxis (city_slug);
CREATE INDEX robotaxis_country_slug_idx ON public.robotaxis (country_slug);

CREATE TRIGGER update_robotaxis_updated_at
BEFORE UPDATE ON public.robotaxis
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();
