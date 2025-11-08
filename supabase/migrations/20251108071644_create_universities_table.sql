-- Migration: create_universities_table

CREATE TABLE public.universities (
  id BIGSERIAL PRIMARY KEY,
  slug TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  website TEXT,
  country_iso TEXT CHECK (
    country_iso IS NULL OR (
      char_length(country_iso) = 2 AND country_iso = upper(country_iso)
    )
  ),
  latitude NUMERIC(9,6),
  longitude NUMERIC(9,6),
  city_name TEXT,
  city_slug TEXT NOT NULL REFERENCES public.cities(slug) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

COMMENT ON COLUMN public.universities.slug IS 'Stable university identifier (e.g. ``university-of-tokyo-jp``)';
COMMENT ON COLUMN public.universities.city_slug IS 'Foreign key to ``public.cities.slug``';

CREATE INDEX universities_city_slug_idx ON public.universities (city_slug);

CREATE TRIGGER update_universities_updated_at
BEFORE UPDATE ON public.universities
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();

