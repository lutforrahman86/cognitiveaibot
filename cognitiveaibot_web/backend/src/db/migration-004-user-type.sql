-- Add user type (admin, user) for role-based access
ALTER TABLE users ADD COLUMN IF NOT EXISTS type VARCHAR(50) DEFAULT 'user';
