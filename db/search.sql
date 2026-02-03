-- MARC to Dublin Core Crosswalk:
-- https://www.loc.gov/marc/marc2dc.html
-- id ==> books.id
-- 100$a is contributor => books.author
-- 245$a$b is title => books.title + title_remainder + books.series.name + volume
-- 260$c is dateOfPubliation => books.publications.date
-- 650$a$b$v$x$y$z subject => books.subjects.heading + subheading + general + chron + geo + form
CREATE UNLOGGED MATERIALIZED VIEW mv_search AS
SELECT
    b.id,
    jsonb_build_object(
        'id', COALESCE(
            (SELECT number FROM identifiers 
             WHERE book_id = b.id AND number LIKE '%OCoLC%' 
             LIMIT 1), 
            ''
        ),
        'contributor', COALESCE(b.author, ''),
        'title', CONCAT_WS(' ', 
            b.title, 
            b.title_remainder, 
            STRING_AGG(s.name, ' '),
            STRING_AGG(s.volume, ' ')
        ),
        'date', COALESCE(STRING_AGG(p.date, ' '), ''),
        'subject', CONCAT_WS(' ',
            STRING_AGG(subj.heading, ' '),
            STRING_AGG(subj.subheading, ' '),
            STRING_AGG(unnest_form, ' '),
            STRING_AGG(unnest_general, ' '),
            STRING_AGG(unnest_chron, ' '),
            STRING_AGG(unnest_geo, ' ')
        )
    ) AS doc
FROM books b
LEFT JOIN series s ON s.book_id = b.id
LEFT JOIN publications p ON p.book_id = b.id
LEFT JOIN subjects subj ON subj.book_id = b.id
LEFT JOIN LATERAL UNNEST(subj.form) AS unnest_form ON TRUE
LEFT JOIN LATERAL UNNEST(subj.general) AS unnest_general ON TRUE
LEFT JOIN LATERAL UNNEST(subj.chron) AS unnest_chron ON TRUE
LEFT JOIN LATERAL UNNEST(subj.geo) AS unnest_geo ON TRUE
GROUP BY b.id, b.author, b.title, b.title_remainder;

CREATE UNIQUE INDEX ON mv_search (id);
CREATE INDEX ON mv_search USING GIN (doc);