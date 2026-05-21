-- 9Router PostgreSQL Initialization
-- Create database (if not exists)

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Set encoding
SET ENCODING TO 'UTF8';
