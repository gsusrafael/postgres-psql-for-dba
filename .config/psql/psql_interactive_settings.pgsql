-- vim: ft=pgsql

-----------------------------------------
-- psql interactive settings           --
-- Author : Jesus Rafael Sanchez       --
-----------------------------------------

-- Disabling pager for later setup
\set PAGER OFF

-- History file management
\set HISTFILE ~/.psql_history- :DBNAME
\set HISTSIZE 2000

-- Show hidden (internal) queries
\set ECHO_HIDDEN ON

-- Completion case configuration
\set COMP_KEYWORD_CASE upper

-- Action on error rollback
\set ON_ERROR_ROLLBACK interactive

-- psql enconding
\encoding unicode

-- Setting NULL symbol
\pset null †

-- Configuring line and table border
\pset linestyle unicode
\pset border 2
\pset pager always

-- Editor settings
\setenv PSQL_EDITOR_LINENUMBER_ARG '+'
\setenv PSQL_EDITOR 'vim +"set syntax=pgsql" '

-- Setting pager
\setenv PAGER less
\setenv LESS '-iMSx4 -FX'

-- ----------------------------------------------------------------------------
-- There is option to use pspg (https://github.com/okbob/pspg), which is an
-- specialized PostgreSQL pager designed to ease the data presentation:
--
-- \setenv PAGER 'pspg '
--
-- ----------------------------------------------------------------------------

\timing on

