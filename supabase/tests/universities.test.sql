begin;
select plan(22);

select has_table('public', 'universities', 'universities table exists');

select has_column('public', 'universities', 'id', 'universities.id column exists');
select has_column('public', 'universities', 'slug', 'universities.slug column exists');
select has_column('public', 'universities', 'name', 'universities.name column exists');
select has_column('public', 'universities', 'website', 'universities.website column exists');
select has_column('public', 'universities', 'country_iso', 'universities.country_iso column exists');
select has_column('public', 'universities', 'latitude', 'universities.latitude column exists');
select has_column('public', 'universities', 'longitude', 'universities.longitude column exists');
select has_column('public', 'universities', 'city_name', 'universities.city_name column exists');
select has_column('public', 'universities', 'city_slug', 'universities.city_slug column exists');
select has_column('public', 'universities', 'created_at', 'universities.created_at column exists');
select has_column('public', 'universities', 'updated_at', 'universities.updated_at column exists');

select ok(
    exists (
        select 1
        from pg_constraint
        where conrelid = to_regclass('public.universities')
          and contype = 'p'
    ),
    'universities has a primary key'
);

select ok(
    exists (
        select 1
        from pg_constraint c
        join pg_attribute a
          on a.attrelid = c.conrelid
         and a.attnum = any (c.conkey)
        where c.conrelid = to_regclass('public.universities')
          and c.contype = 'u'
          and a.attname = 'slug'
    ),
    'universities.slug has a unique constraint'
);

select ok(
    exists (
        select 1
        from pg_constraint
        where conrelid = to_regclass('public.universities')
          and contype = 'f'
          and confrelid = to_regclass('public.cities')
    ),
    'universities.city_slug references public.cities'
);

select has_index('public', 'universities', 'universities_city_slug_idx', 'universities.city_slug index exists');

insert into public.countries (slug, name, iso_3166_1_alpha_2, iso_3166_1_alpha_3)
values ('test-country-universities', 'Test Country Universities', 'TU', 'TCU');

insert into public.cities (slug, city, latitude, longitude, country_slug)
values ('test-city-universities', 'Test City Universities', 12.345678, 98.765432, 'test-country-universities');

insert into public.universities (slug, name, website, country_iso, latitude, longitude, city_name, city_slug)
values (
    'test-university',
    'Test University',
    'https://example.edu',
    'TU',
    10.123456,
    20.654321,
    'Test City Universities',
    'test-city-universities'
);

insert into public.universities (slug, name, city_name, city_slug)
values (
    'test-university-no-country',
    'Test University No Country',
    'Test City Universities',
    'test-city-universities'
);

select ok(
    (select created_at is not null from public.universities where slug = 'test-university'),
    'created_at defaults to now()'
);

select ok(
    (select updated_at is not null from public.universities where slug = 'test-university'),
    'updated_at defaults to now()'
);

select ok(
    (select country_iso is null from public.universities where slug = 'test-university-no-country'),
    'country_iso can be null'
);

select throws_ok(
    $$
    insert into public.universities (slug, name, city_slug, country_iso)
    values ('invalid-country-iso-university', 'Invalid Country ISO University', 'test-city-universities', 'tu')
    $$,
    '23514',
    'new row for relation "universities" violates check constraint "universities_country_iso_check"'
);

select throws_ok(
    $$
    insert into public.universities (slug, name, city_slug)
    values ('test-university', 'Duplicate Slug University', 'test-city-universities')
    $$,
    'duplicate key value violates unique constraint "universities_slug_key"',
    'slug must be unique'
);

select throws_ok(
    $$
    insert into public.universities (slug, name, city_slug)
    values ('missing-city-university', 'Missing City University', 'nonexistent-city-slug')
    $$,
    '23503',
    'insert or update on table "universities" violates foreign key constraint "universities_city_slug_fkey"'
);

select * from finish();
rollback;

