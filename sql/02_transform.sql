UPDATE staging.stg_test SET team = 'Curaçao' WHERE team LIKE 'Cura%o' AND team != 'Curaçao';

-- ============================================
-- dim_country: one row per canonical country
-- ============================================
TRUNCATE TABLE dim_country RESTART IDENTITY CASCADE;

INSERT INTO dim_country (country_name, confederation, fifa_rank)
SELECT DISTINCT
    COALESCE(m.canonical_name, t.team) AS country_name,
    t.confederation,
    t.fifa_rank
FROM staging.stg_wc_2026_teams t
LEFT JOIN staging.country_name_map m ON m.raw_name = t.team
ON CONFLICT (country_name) DO NOTHING;

INSERT INTO dim_country (country_name)
SELECT DISTINCT COALESCE(m.canonical_name, tr.team)
FROM staging.stg_train tr
LEFT JOIN staging.country_name_map m ON m.raw_name = tr.team
WHERE COALESCE(m.canonical_name, tr.team) NOT IN (SELECT country_name FROM dim_country)
ON CONFLICT (country_name) DO NOTHING;

INSERT INTO dim_country (country_name)
SELECT DISTINCT COALESCE(m.canonical_name, wa.team1)
FROM staging.stg_wc_all_matches wa
LEFT JOIN staging.country_name_map m ON m.raw_name = wa.team1
WHERE COALESCE(m.canonical_name, wa.team1) NOT IN (SELECT country_name FROM dim_country)
ON CONFLICT (country_name) DO NOTHING;

INSERT INTO dim_country (country_name)
SELECT DISTINCT COALESCE(m.canonical_name, wa.team2)
FROM staging.stg_wc_all_matches wa
LEFT JOIN staging.country_name_map m ON m.raw_name = wa.team2
WHERE COALESCE(m.canonical_name, wa.team2) NOT IN (SELECT country_name FROM dim_country)
ON CONFLICT (country_name) DO NOTHING;

-- ============================================
-- dim_tournament_edition: one row per World Cup year
-- ============================================
TRUNCATE TABLE dim_tournament_edition RESTART IDENTITY CASCADE;

INSERT INTO dim_tournament_edition (year, host_nation, champion, runner_up, total_goals, attendance)
SELECT year, host, champion, runner_up, goals, attendance
FROM staging.stg_wc_all_editions
ON CONFLICT (year) DO NOTHING;

INSERT INTO dim_tournament_edition (year, host_nation)
VALUES (2026, 'United States / Mexico / Canada')
ON CONFLICT (year) DO NOTHING;
-- ============================================
-- dim_player: one row per unique player (2026 squads)
-- ============================================
TRUNCATE TABLE dim_player RESTART IDENTITY CASCADE;

INSERT INTO dim_player (player_name, country_id, position, club)
SELECT DISTINCT
    p.player,
    dc.country_id,
    p.position,
    p.club
FROM staging.stg_players p
LEFT JOIN staging.country_name_map m ON m.raw_name = p.team_country
LEFT JOIN dim_country dc ON dc.country_name = COALESCE(m.canonical_name, p.team_country);

-- ============================================
-- fact_matches: historical match results
-- ============================================
TRUNCATE TABLE fact_matches RESTART IDENTITY CASCADE;

INSERT INTO fact_matches (edition_id, home_country_id, away_country_id, home_score, away_score, stage, venue, match_date, notes)
SELECT
    te.edition_id,
    dc1.country_id,
    dc2.country_id,
    wa.score1,
    wa.score2,
    wa.stage,
    wa.venue,
    wa.date::date,
    wa.notes
FROM staging.stg_wc_all_matches wa
LEFT JOIN dim_tournament_edition te ON te.year = wa.year
LEFT JOIN staging.country_name_map m1 ON m1.raw_name = wa.team1
LEFT JOIN dim_country dc1 ON dc1.country_name = COALESCE(m1.canonical_name, wa.team1)
LEFT JOIN staging.country_name_map m2 ON m2.raw_name = wa.team2
LEFT JOIN dim_country dc2 ON dc2.country_name = COALESCE(m2.canonical_name, wa.team2);

-- ============================================
-- fact_player_stats: 2026 player performance
-- ============================================
TRUNCATE TABLE fact_player_stats RESTART IDENTITY CASCADE;

INSERT INTO fact_player_stats (player_id, edition_id, goals, assists, penalties, matches_played)
SELECT
    dp.player_id,
    (SELECT edition_id FROM dim_tournament_edition WHERE year = 2026),
    p.goals,
    p.assists,
    p.pens_made,
    p.games
FROM staging.stg_players p
LEFT JOIN staging.country_name_map m ON m.raw_name = p.team_country
LEFT JOIN dim_country dc ON dc.country_name = COALESCE(m.canonical_name, p.team_country)
LEFT JOIN dim_player dp ON dp.player_name = p.player AND dp.country_id = dc.country_id;

-- ============================================
-- fact_team_stats: 2026 team performance
-- ============================================
TRUNCATE TABLE fact_team_stats RESTART IDENTITY CASCADE;

INSERT INTO fact_team_stats (country_id, edition_id, goals_for, goals_against, shots, possession_pct, yellow_cards, red_cards, squad_age_avg)
SELECT
    dc.country_id,
    (SELECT edition_id FROM dim_tournament_edition WHERE year = 2026),
    t.goals,
    t.goals_against,
    t.shots,
    t.possession,
    t.cards_yellow,
    t.cards_red,
    t.avg_age
FROM staging.stg_teams t
LEFT JOIN staging.country_name_map m ON m.raw_name = t.team_country
LEFT JOIN dim_country dc ON dc.country_name = COALESCE(m.canonical_name, t.team_country);