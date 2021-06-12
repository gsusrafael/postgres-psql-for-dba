-- vim: ft=pgsql

-----------------------------------------
-- psql promtp settings                --
-- Author : Jesus Rafael Sanchez       --
-----------------------------------------

-- Mute psql
\set QUIET ON

-- Check if is superuser
select current_setting('is_superuser') is_superuser \gset

-- PROMPT1 and PROMPT2 Settings
\set PROMPT1 '%[%033[1;34;40m%]%M%[%033[0m%]:%[%033[1;36;40m%]%> %[%033[1;32;40m%]%n%[%033[0;36;40m%]@%[%033[1;33;40m%]%/%[%033[0;32;40m%]%R%#%[%033[0m%] '
\set PROMPT2 '%[%033[1;34;40m%]%R%[%033[0m%] %[%033[1;32;40m%]%n%[%033[0;36;40m%]@%[%033[1;33;40m%]%/%[%033[0;32;40m%]% %#%[%033[0m%] '

-- Unmute psql
\set QUIET OFF
