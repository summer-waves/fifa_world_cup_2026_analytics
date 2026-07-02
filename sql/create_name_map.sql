DROP TABLE IF EXISTS staging.country_name_map;

CREATE TABLE staging.country_name_map (
    raw_name        TEXT PRIMARY KEY,
    canonical_name  TEXT NOT NULL
);

INSERT INTO staging.country_name_map (raw_name, canonical_name) VALUES
    ('USA', 'United States'),
    ('United States', 'United States'),
    ('Korea Republic', 'South Korea'),
    ('South Korea', 'South Korea'),
    ('Cabo Verde', 'Cape Verde'),
    ('Cape Verde', 'Cape Verde'),
    ('Congo DR', 'DR Congo'),
    ('Cura?o', 'Curaçao'),
    ('DR Congo', 'DR Congo'),
    ('Côte d''Ivoire', 'Ivory Coast'),
    ('Ivory Coast', 'Ivory Coast'),
    ('Czechia', 'Czech Republic'),
    ('Czech Republic', 'Czech Republic'),
    ('Bosnia and Herzegovina', 'Bosnia and Herzegovina'),
    ('Bosnia–Herz', 'Bosnia and Herzegovina'),
    ('IR Iran', 'Iran'),
    ('Iran', 'Iran'),
    ('Türkiye', 'Turkey'),
    ('Turkey', 'Turkey');