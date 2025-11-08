-- Migration: create_countries_and_cities_by_slug

------------------------------------------------------------
-- COUNTRIES
------------------------------------------------------------
CREATE TABLE public.countries (
  slug TEXT PRIMARY KEY,                     -- use slug as PK (e.g. 'japan')
  name TEXT NOT NULL,
  iso_3166_1_alpha_2 CHAR(2) NOT NULL,
  iso_3166_1_alpha_3 CHAR(3) NOT NULL,
  iso_3166_1_numeric CHAR(3),
  capital TEXT,
  region TEXT,
  subregion TEXT,
  population BIGINT,
  area_km2 NUMERIC(12,2),
  latitude NUMERIC(9,6),
  longitude NUMERIC(9,6),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

------------------------------------------------------------
-- CITIES
------------------------------------------------------------
CREATE TABLE public.cities (
  id SERIAL PRIMARY KEY,
  slug TEXT UNIQUE NOT NULL,                         -- e.g. 'tokyo-japan'
  city TEXT NOT NULL,
  city_ascii TEXT,
  latitude NUMERIC(9,6) NOT NULL,
  longitude NUMERIC(9,6) NOT NULL,
  admin_name TEXT,
  capital TEXT CHECK (capital IN ('primary', 'admin', 'minor', 'none')) DEFAULT 'none',
  population BIGINT,
  source_id BIGINT,
  country_slug TEXT NOT NULL REFERENCES public.countries(slug) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

------------------------------------------------------------
-- Trigger for updated_at
------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_countries_updated_at
BEFORE UPDATE ON public.countries
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_cities_updated_at
BEFORE UPDATE ON public.cities
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();