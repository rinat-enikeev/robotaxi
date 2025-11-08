-- Migration: create_ridehailing_operations_tables

CREATE TABLE public.ridehailing_country_operations (
  id BIGSERIAL PRIMARY KEY,
  ridehailing_slug TEXT NOT NULL REFERENCES public.ridehailings(slug) ON DELETE CASCADE,
  country_slug TEXT NOT NULL REFERENCES public.countries(slug) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  UNIQUE (ridehailing_slug, country_slug)
);

CREATE TABLE public.ridehailing_city_operations (
  id BIGSERIAL PRIMARY KEY,
  ridehailing_slug TEXT NOT NULL REFERENCES public.ridehailings(slug) ON DELETE CASCADE,
  city_slug TEXT NOT NULL REFERENCES public.cities(slug) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  UNIQUE (ridehailing_slug, city_slug)
);

CREATE INDEX ridehailing_country_operations_country_idx
  ON public.ridehailing_country_operations (country_slug);

CREATE INDEX ridehailing_country_operations_ridehailing_idx
  ON public.ridehailing_country_operations (ridehailing_slug);

CREATE INDEX ridehailing_city_operations_city_idx
  ON public.ridehailing_city_operations (city_slug);

CREATE INDEX ridehailing_city_operations_ridehailing_idx
  ON public.ridehailing_city_operations (ridehailing_slug);

CREATE TRIGGER update_ridehailing_country_operations_updated_at
BEFORE UPDATE ON public.ridehailing_country_operations
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_ridehailing_city_operations_updated_at
BEFORE UPDATE ON public.ridehailing_city_operations
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();

