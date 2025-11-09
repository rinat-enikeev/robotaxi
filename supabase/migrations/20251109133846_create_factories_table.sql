-- Migration: create_factories_table
-- Note: factory city values reference city slugs in public.cities

CREATE TABLE public.factories (
  id BIGSERIAL PRIMARY KEY,
  slug TEXT UNIQUE NOT NULL,
  city_slug TEXT NOT NULL REFERENCES public.cities(slug) ON DELETE CASCADE,
  manufacturer TEXT NOT NULL,
  focus TEXT[],
  brand TEXT[],
  address TEXT,
  rank INTEGER,
  selection TEXT,
  latitude NUMERIC(9,6) NOT NULL,
  longitude NUMERIC(9,6) NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  CHECK (rank IS NULL OR rank >= 0)
);

CREATE INDEX factories_city_slug_idx ON public.factories (city_slug);
CREATE INDEX factories_manufacturer_idx ON public.factories (manufacturer);

CREATE TRIGGER update_factories_updated_at
BEFORE UPDATE ON public.factories
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();


