begin;
select plan(24);

select has_table('public', 'cities', 'cities table exists');

select has_column('public', 'cities', 'id', 'cities.id column exists');
select has_column('public', 'cities', 'slug', 'cities.slug column exists');
select has_column('public', 'cities', 'city', 'cities.city column exists');
select has_column('public', 'cities', 'city_ascii', 'cities.city_ascii column exists');
select has_column('public', 'cities', 'latitude', 'cities.latitude column exists');
select has_column('public', 'cities', 'longitude', 'cities.longitude column exists');
select has_column('public', 'cities', 'admin_name', 'cities.admin_name column exists');
select has_column('public', 'cities', 'capital', 'cities.capital column exists');
select has_column('public', 'cities', 'population', 'cities.population column exists');
select has_column('public', 'cities', 'source_id', 'cities.source_id column exists');
select has_column('public', 'cities', 'country_slug', 'cities.country_slug column exists');
select has_column('public', 'cities', 'created_at', 'cities.created_at column exists');
select has_column('public', 'cities', 'updated_at', 'cities.updated_at column exists');

select ok(
    exists (
        select 1
        from pg_constraint
        where conrelid = 'public.cities'::regclass
          and contype = 'p'
    ),
    'cities has a primary key'
);

select ok(
    exists (
        select 1
        from pg_constraint c
        join pg_attribute a
          on a.attrelid = c.conrelid
         and a.attnum = any (c.conkey)
        where c.conrelid = 'public.cities'::regclass
          and c.contype = 'u'
          and a.attname = 'slug'
    ),
    'cities.slug has a unique constraint'
);

select ok(
    exists (
        select 1
        from pg_constraint
        where conrelid = 'public.cities'::regclass
          and contype = 'f'
          and confrelid = 'public.countries'::regclass
    ),
    'cities.country_slug references public.countries'
);

insert into public.countries (slug, name, iso_3166_1_alpha_2, iso_3166_1_alpha_3, iso_3166_1_numeric, capital, region, subregion, population, area_km2, latitude, longitude)
values ('test-country', 'Test Country', 'TC', 'TST', '999', 'Test City', 'Test Region', 'Test Subregion', 123456, 123.45, 12.345678, 98.765432);

insert into public.cities (slug, city, city_ascii, latitude, longitude, admin_name, capital, population, source_id, country_slug)
values ('test-city', 'Test City', 'Test City', 12.345678, 98.765432, 'Test Admin', 'admin', 987654, 42, 'test-country');

select is(
    (select capital from public.cities where slug = 'test-city'),
    'admin',
    'capital can be set explicitly'
);

insert into public.cities (slug, city, latitude, longitude, country_slug)
values ('test-city-default-capital', 'Default Capital City', 11.111111, 22.222222, 'test-country');
select is(
    (select capital from public.cities where slug = 'test-city-default-capital'),
    'none',
    'capital defaults to none'
);

select ok(
    (select created_at is not null from public.cities where slug = 'test-city-default-capital'),
    'created_at defaults to now()'
);

select ok(
    (select updated_at is not null from public.cities where slug = 'test-city-default-capital'),
    'updated_at defaults to now()'
);

select throws_ok(
    $$
    insert into public.cities (slug, city, latitude, longitude, country_slug, capital)
    values ('invalid-capital-city', 'Invalid Capital City', 33.333333, 44.444444, 'test-country', 'invalid')
    $$,
    '23514',
    'capital only allows expected values'
);

select throws_ok(
    $$
    insert into public.cities (slug, city, latitude, longitude, country_slug)
    values ('test-city', 'Duplicate Slug City', 55.555555, 66.666666, 'test-country')
    $$,
    'duplicate key value violates unique constraint "cities_slug_key"',
    'slug must be unique'
);

select throws_ok(
    $$
    insert into public.cities (slug, city, latitude, longitude, country_slug)
    values ('no-country-city', 'No Country City', 77.777777, 88.888888, 'missing-country')
    $$,
    '23503',
    'country_slug must reference an existing country'
);

select * from finish();
rollback;
