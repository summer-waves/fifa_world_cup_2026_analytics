-- Dimensions
CREATE TABLE dim_country (
    country_id      SERIAL PRIMARY KEY,
    country_name    TEXT UNIQUE NOT NULL,
    confederation   TEXT,
    fifa_rank       INT
);

CREATE TABLE dim_player (
    player_id       SERIAL PRIMARY KEY,
    player_name     TEXT NOT NULL,
    country_id      INT REFERENCES dim_country(country_id),
    position        TEXT,
    club            TEXT,
    date_of_birth   DATE
);

CREATE TABLE dim_tournament_edition (
    edition_id      SERIAL PRIMARY KEY,
    year            INT UNIQUE NOT NULL,
    host_nation     TEXT,
    champion        TEXT,
    runner_up       TEXT,
    total_goals     INT,
    attendance      BIGINT
);

-- Facts
CREATE TABLE fact_matches (
    match_id        SERIAL PRIMARY KEY,
    edition_id      INT REFERENCES dim_tournament_edition(edition_id),
    home_country_id INT REFERENCES dim_country(country_id),
    away_country_id INT REFERENCES dim_country(country_id),
    home_score      INT,
    away_score      INT,
    stage           TEXT,
    venue           TEXT,
    match_date      DATE,
    notes           TEXT
);

CREATE TABLE fact_player_stats (
    stat_id         SERIAL PRIMARY KEY,
    player_id       INT REFERENCES dim_player(player_id),
    edition_id      INT REFERENCES dim_tournament_edition(edition_id),
    goals           INT DEFAULT 0,
    assists         INT DEFAULT 0,
    penalties       INT DEFAULT 0,
    matches_played  INT DEFAULT 0,
    stat_date       DATE DEFAULT CURRENT_DATE
);

CREATE TABLE fact_team_stats (
    team_stat_id    SERIAL PRIMARY KEY,
    country_id      INT REFERENCES dim_country(country_id),
    edition_id      INT REFERENCES dim_tournament_edition(edition_id),
    goals_for       INT,
    goals_against   INT,
    shots           INT,
    possession_pct  NUMERIC(5,2),
    yellow_cards    INT,
    red_cards       INT,
    squad_age_avg   NUMERIC(4,1),
    market_value    NUMERIC(12,2),
    stat_date       DATE DEFAULT CURRENT_DATE
);

-- Predictions table: Python writes here, Power BI reads from here
CREATE TABLE predictions (
    prediction_id       SERIAL PRIMARY KEY,
    country_id          INT REFERENCES dim_country(country_id),
    edition_id          INT REFERENCES dim_tournament_edition(edition_id),
    predicted_stage     TEXT,
    win_probability      NUMERIC(5,4),
    model_version        TEXT,
    predicted_at          TIMESTAMP DEFAULT NOW()
);
