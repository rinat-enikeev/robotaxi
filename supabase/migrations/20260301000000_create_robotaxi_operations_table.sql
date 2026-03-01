-- Migration: create_robotaxi_city_operations_table

CREATE TABLE public.robotaxi_city_operations (
  id BIGSERIAL PRIMARY KEY,
  robotaxi_slug TEXT NOT NULL REFERENCES public.robotaxis(slug) ON DELETE CASCADE,
  city_slug TEXT NOT NULL REFERENCES public.cities(slug) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  UNIQUE (robotaxi_slug, city_slug)
);

CREATE INDEX robotaxi_city_operations_city_idx
  ON public.robotaxi_city_operations (city_slug);

CREATE INDEX robotaxi_city_operations_robotaxi_idx
  ON public.robotaxi_city_operations (robotaxi_slug);

CREATE TRIGGER update_robotaxi_city_operations_updated_at
BEFORE UPDATE ON public.robotaxi_city_operations
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();
