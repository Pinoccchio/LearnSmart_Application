-- =============================================================================
-- LearnSmart Complete Database Schema v2.0
-- Single file deployment for Supabase SQL Editor
-- =============================================================================
-- Copy and paste this entire file into Supabase SQL Editor and run it
-- This will create/update all tables, types, functions, indexes, and sample data
-- Includes: Users, Courses, Modules, Course Materials, Quizzes, Quiz Attempts
-- Last Updated: January 2025 - Added instructor course management & AI quiz system
-- =============================================================================

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =============================================================================
-- 1. CUSTOM TYPES
-- =============================================================================

-- User Role Enum Type
DROP TYPE IF EXISTS user_role CASCADE;
CREATE TYPE user_role AS ENUM ('admin', 'instructor', 'student');

-- User Status Enum Type  
DROP TYPE IF EXISTS user_status CASCADE;
CREATE TYPE user_status AS ENUM ('active', 'inactive', 'suspended');

-- Study Technique Enum Type
DROP TYPE IF EXISTS study_technique CASCADE;
CREATE TYPE study_technique AS ENUM ('active_recall', 'feynman_technique', 'pomodoro_technique', 'retrieval_practice');

-- =============================================================================
-- 2. UTILITY FUNCTIONS
-- =============================================================================

-- Function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to create user profile when auth user is created
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.users (id, email, name)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1))
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update user last login timestamp
CREATE OR REPLACE FUNCTION update_user_last_login(user_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE public.users 
  SET 
    last_login = NOW(),
    updated_at = NOW()
  WHERE id = user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- 3. MAIN TABLES
-- =============================================================================

-- Users Table (extends auth.users with additional profile information)
DROP TABLE IF EXISTS public.users CASCADE;
CREATE TABLE public.users (
  id UUID REFERENCES auth.users(id) PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  role user_role DEFAULT 'student'::user_role,
  status user_status DEFAULT 'active'::user_status,
  profile_picture TEXT,
  last_login TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Courses Table
DROP TABLE IF EXISTS public.courses CASCADE;
CREATE TABLE public.courses (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  image_url TEXT,
  instructor_id UUID REFERENCES public.users(id),
  created_by UUID REFERENCES public.users(id),
  status TEXT DEFAULT 'active',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Modules Table (with sequential learning support)
DROP TABLE IF EXISTS public.modules CASCADE;
CREATE TABLE public.modules (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  course_id UUID REFERENCES public.courses(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT, -- Optional description (removed NOT NULL constraint)
  order_index INTEGER NOT NULL,
  available_techniques JSONB DEFAULT '["active_recall", "feynman_technique", "pomodoro_technique", "retrieval_practice"]'::jsonb,
  -- Sequential learning fields
  prerequisite_module_id UUID REFERENCES public.modules(id) ON DELETE SET NULL,
  passing_threshold INTEGER DEFAULT 80,
  is_locked BOOLEAN DEFAULT false,
  created_by UUID REFERENCES public.users(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  -- Constraints
  CONSTRAINT check_passing_threshold CHECK (passing_threshold >= 0 AND passing_threshold <= 100)
);

-- Course Materials Table (for storing PDF uploads and documents)
DROP TABLE IF EXISTS public.course_materials CASCADE;
CREATE TABLE public.course_materials (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  module_id UUID REFERENCES public.modules(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  file_url TEXT NOT NULL, -- Supabase Storage URL
  file_type TEXT NOT NULL, -- 'pdf', 'doc', 'docx', 'txt'
  file_size BIGINT, -- File size in bytes
  file_name TEXT NOT NULL, -- Original filename
  order_index INTEGER DEFAULT 0, -- For organizing materials within a module
  created_by UUID REFERENCES public.users(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Quizzes Table (for storing AI-generated and manual quizzes)
DROP TABLE IF EXISTS public.quizzes CASCADE;
CREATE TABLE public.quizzes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  module_id UUID REFERENCES public.modules(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  questions JSONB NOT NULL, -- Store quiz questions as JSON array
  time_limit INTEGER, -- Time limit in minutes (optional)
  passing_score INTEGER DEFAULT 70, -- Passing score percentage
  ai_generated BOOLEAN DEFAULT false, -- Whether quiz was AI-generated
  study_technique VARCHAR(50) DEFAULT 'general', -- Study technique used for generation
  source_material_id UUID REFERENCES public.course_materials(id), -- Link to PDF used for generation
  status TEXT DEFAULT 'draft', -- 'draft', 'published', 'archived'
  created_by UUID REFERENCES public.users(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  -- Add constraint to ensure only valid study techniques
  CONSTRAINT chk_study_technique CHECK (study_technique IN ('general', 'active_recall', 'feynman', 'retrieval_practice', 'pomodoro'))
);

-- Quiz Attempts Table (for tracking student quiz submissions)
DROP TABLE IF EXISTS public.quiz_attempts CASCADE;
CREATE TABLE public.quiz_attempts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  quiz_id UUID REFERENCES public.quizzes(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  answers JSONB NOT NULL, -- Store student answers as JSON
  score INTEGER, -- Score achieved (percentage)
  completed BOOLEAN DEFAULT false,
  time_taken INTEGER, -- Time taken in seconds
  study_technique_used TEXT, -- Study technique used during attempt
  started_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  completed_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- User Progress Table
DROP TABLE IF EXISTS public.user_progress CASCADE;
CREATE TABLE public.user_progress (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  course_id UUID REFERENCES public.courses(id) ON DELETE CASCADE,
  completion_percentage DECIMAL(5,2) DEFAULT 0.0,
  study_streak INTEGER DEFAULT 0,
  total_study_time INTEGER DEFAULT 0, -- in minutes
  last_activity_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, course_id)
);

-- Module Progress Table
DROP TABLE IF EXISTS public.module_progress CASCADE;
CREATE TABLE public.module_progress (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  module_id UUID REFERENCES public.modules(id) ON DELETE CASCADE,
  is_completed BOOLEAN DEFAULT FALSE,
  completion_date TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, module_id)
);

-- Study Sessions Table
DROP TABLE IF EXISTS public.study_sessions CASCADE;
CREATE TABLE public.study_sessions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  module_id UUID REFERENCES public.modules(id) ON DELETE CASCADE,
  technique TEXT NOT NULL,
  duration_minutes INTEGER NOT NULL DEFAULT 0,
  completed BOOLEAN DEFAULT FALSE,
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =============================================================================
-- 4. PERFORMANCE INDEXES
-- =============================================================================

-- Users table indexes
CREATE INDEX IF NOT EXISTS idx_users_email ON public.users(email);
CREATE INDEX IF NOT EXISTS idx_users_role ON public.users(role);
CREATE INDEX IF NOT EXISTS idx_users_status ON public.users(status);
CREATE INDEX IF NOT EXISTS idx_users_last_login ON public.users(last_login);

-- Courses table indexes
CREATE INDEX IF NOT EXISTS idx_courses_instructor ON public.courses(instructor_id);
CREATE INDEX IF NOT EXISTS idx_courses_created_by ON public.courses(created_by);
CREATE INDEX IF NOT EXISTS idx_courses_status ON public.courses(status);

-- Modules table indexes
CREATE INDEX IF NOT EXISTS idx_modules_course ON public.modules(course_id);
CREATE INDEX IF NOT EXISTS idx_modules_course_id ON public.modules(course_id);
CREATE INDEX IF NOT EXISTS idx_modules_order ON public.modules(course_id, order_index);
-- Sequential learning indexes
CREATE INDEX IF NOT EXISTS idx_modules_prerequisite ON public.modules(prerequisite_module_id);
CREATE INDEX IF NOT EXISTS idx_modules_created_by ON public.modules(created_by);

-- User Progress table indexes
CREATE INDEX IF NOT EXISTS idx_user_progress_user ON public.user_progress(user_id);
CREATE INDEX IF NOT EXISTS idx_user_progress_course ON public.user_progress(course_id);

-- Module Progress table indexes
CREATE INDEX IF NOT EXISTS idx_module_progress_user ON public.module_progress(user_id);
CREATE INDEX IF NOT EXISTS idx_module_progress_module ON public.module_progress(module_id);

-- Study Sessions table indexes
CREATE INDEX IF NOT EXISTS idx_study_sessions_user ON public.study_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_study_sessions_module ON public.study_sessions(module_id);
CREATE INDEX IF NOT EXISTS idx_study_sessions_created ON public.study_sessions(created_at);

-- Course Materials table indexes
CREATE INDEX IF NOT EXISTS idx_course_materials_module ON public.course_materials(module_id);
CREATE INDEX IF NOT EXISTS idx_course_materials_created_by ON public.course_materials(created_by);
CREATE INDEX IF NOT EXISTS idx_course_materials_order ON public.course_materials(module_id, order_index);
CREATE INDEX IF NOT EXISTS idx_course_materials_file_type ON public.course_materials(file_type);

-- Quizzes table indexes  
CREATE INDEX IF NOT EXISTS idx_quizzes_module ON public.quizzes(module_id);
CREATE INDEX IF NOT EXISTS idx_quizzes_created_by ON public.quizzes(created_by);
CREATE INDEX IF NOT EXISTS idx_quizzes_source_material ON public.quizzes(source_material_id);
CREATE INDEX IF NOT EXISTS idx_quizzes_status ON public.quizzes(status);
CREATE INDEX IF NOT EXISTS idx_quizzes_study_technique ON public.quizzes(study_technique);
CREATE INDEX IF NOT EXISTS idx_quizzes_ai_generated ON public.quizzes(ai_generated);

-- Quiz Attempts table indexes
CREATE INDEX IF NOT EXISTS idx_quiz_attempts_quiz ON public.quiz_attempts(quiz_id);
CREATE INDEX IF NOT EXISTS idx_quiz_attempts_user ON public.quiz_attempts(user_id);
CREATE INDEX IF NOT EXISTS idx_quiz_attempts_completed_at ON public.quiz_attempts(completed_at);
CREATE INDEX IF NOT EXISTS idx_quiz_attempts_score ON public.quiz_attempts(score);
CREATE INDEX IF NOT EXISTS idx_quiz_attempts_study_technique ON public.quiz_attempts(study_technique_used);

-- =============================================================================
-- 5. DASHBOARD ANALYTICS VIEW
-- =============================================================================

-- Dashboard Statistics View for admin analytics
CREATE OR REPLACE VIEW dashboard_stats AS
SELECT 
    (SELECT COUNT(*) FROM public.users WHERE role = 'student') as total_students,
    (SELECT COUNT(*) FROM public.users WHERE role = 'student' AND status = 'active') as active_students,
    (SELECT COUNT(*) FROM public.users WHERE role = 'instructor') as total_instructors,
    (SELECT COUNT(*) FROM public.courses) as total_courses,
    (SELECT COUNT(*) FROM public.study_sessions WHERE created_at >= NOW() - INTERVAL '30 days') as sessions_last_30_days,
    (SELECT COUNT(*) FROM public.study_sessions WHERE completed = true AND created_at >= NOW() - INTERVAL '30 days') as completed_sessions_last_30_days,
    (SELECT ROUND(AVG(completion_percentage), 2) FROM public.user_progress) as avg_completion_rate;

-- =============================================================================
-- 6. SCHEMA CACHE REFRESH
-- =============================================================================

-- Refresh PostgREST schema cache to recognize relationships
-- This helps ensure that the API recognizes all table relationships correctly
SELECT pg_notify('pgrst', 'reload schema');

-- =============================================================================
-- 7. TRIGGERS
-- =============================================================================

-- Automatically update updated_at timestamp on all tables
CREATE TRIGGER set_updated_at_users BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION handle_updated_at();
CREATE TRIGGER set_updated_at_courses BEFORE UPDATE ON public.courses FOR EACH ROW EXECUTE FUNCTION handle_updated_at();
CREATE TRIGGER set_updated_at_modules BEFORE UPDATE ON public.modules FOR EACH ROW EXECUTE FUNCTION handle_updated_at();
CREATE TRIGGER set_updated_at_course_materials BEFORE UPDATE ON public.course_materials FOR EACH ROW EXECUTE FUNCTION handle_updated_at();
CREATE TRIGGER set_updated_at_quizzes BEFORE UPDATE ON public.quizzes FOR EACH ROW EXECUTE FUNCTION handle_updated_at();
CREATE TRIGGER set_updated_at_quiz_attempts BEFORE UPDATE ON public.quiz_attempts FOR EACH ROW EXECUTE FUNCTION handle_updated_at();
CREATE TRIGGER set_updated_at_user_progress BEFORE UPDATE ON public.user_progress FOR EACH ROW EXECUTE FUNCTION handle_updated_at();
CREATE TRIGGER set_updated_at_module_progress BEFORE UPDATE ON public.module_progress FOR EACH ROW EXECUTE FUNCTION handle_updated_at();
CREATE TRIGGER set_updated_at_study_sessions BEFORE UPDATE ON public.study_sessions FOR EACH ROW EXECUTE FUNCTION handle_updated_at();

-- Auto-create user profile when auth user is created (DISABLED for development)
-- Uncomment the next line to enable automatic user profile creation
-- CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- =============================================================================
-- 8. ROW LEVEL SECURITY (DISABLED FOR DEVELOPMENT)
-- =============================================================================

-- Enable RLS on all tables (currently disabled for easier development)
-- Uncomment these lines when you're ready to enable security in production

-- ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.courses ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.modules ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.user_progress ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.module_progress ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.study_sessions ENABLE ROW LEVEL SECURITY;

-- Basic RLS Policies (uncomment when enabling RLS)
-- CREATE POLICY "Users can read own profile" ON public.users FOR SELECT USING (auth.uid() = id OR EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('admin', 'instructor')));
-- CREATE POLICY "Admins can manage all users" ON public.users FOR ALL USING (EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin'));

-- =============================================================================
-- 9. PERMISSIONS
-- =============================================================================

-- Grant permissions to authenticated users
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated;

-- Grant permissions to anonymous users (for registration)
GRANT USAGE ON SCHEMA public TO anon;
GRANT INSERT, SELECT ON public.users TO anon;

-- Ensure explicit permissions for user management operations
GRANT ALL ON public.users TO authenticated;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- Grant specific function permissions
GRANT EXECUTE ON FUNCTION update_user_last_login(UUID) TO authenticated;

-- Permissions verification (optional - for debugging)
-- Uncomment the following lines to verify permissions after deployment:
-- SELECT grantee, privilege_type, is_grantable
-- FROM information_schema.table_privileges 
-- WHERE table_schema = 'public' AND table_name = 'users'
-- AND grantee IN ('authenticated', 'anon')
-- ORDER BY grantee, privilege_type;

-- =============================================================================
-- 10. ADDITIONAL CONFIGURATION (RESERVED FOR FUTURE USE)
-- =============================================================================

-- This section is reserved for future configuration options
-- No sample data is included to allow clean database initialization

-- =============================================================================
-- 11. TABLE COMMENTS FOR DOCUMENTATION
-- =============================================================================

-- Users table comments
COMMENT ON TABLE public.users IS 'User profiles that extend Supabase auth.users with additional information';
COMMENT ON COLUMN public.users.id IS 'References auth.users(id) - primary key from Supabase auth';
COMMENT ON COLUMN public.users.email IS 'User email address, must be unique';
COMMENT ON COLUMN public.users.name IS 'Full name of the user';
COMMENT ON COLUMN public.users.role IS 'User role: admin, instructor, or student';
COMMENT ON COLUMN public.users.status IS 'User account status: active, inactive, or suspended';
COMMENT ON COLUMN public.users.profile_picture IS 'URL to user profile picture (optional)';
COMMENT ON COLUMN public.users.last_login IS 'Timestamp of user last login for activity tracking';
COMMENT ON COLUMN public.users.created_at IS 'When the user profile was created';
COMMENT ON COLUMN public.users.updated_at IS 'When the user profile was last updated';

-- Courses table comments
COMMENT ON TABLE public.courses IS 'Criminology courses available in the platform';
COMMENT ON COLUMN public.courses.id IS 'Primary key for the course';
COMMENT ON COLUMN public.courses.title IS 'Course title';
COMMENT ON COLUMN public.courses.description IS 'Detailed course description';
COMMENT ON COLUMN public.courses.image_url IS 'URL to course cover image';
COMMENT ON COLUMN public.courses.instructor_id IS 'Reference to user who teaches the course';
COMMENT ON COLUMN public.courses.created_by IS 'Reference to user who created the course record (admin or instructor)';
COMMENT ON COLUMN public.courses.created_at IS 'Timestamp when the course was created';
COMMENT ON COLUMN public.courses.updated_at IS 'Timestamp when the course was last updated';
COMMENT ON COLUMN public.courses.status IS 'Course status (active, draft, archived, etc.)';

-- Modules table comments
COMMENT ON TABLE public.modules IS 'Individual modules/lessons within courses';
COMMENT ON COLUMN public.modules.id IS 'Primary key for the module';
COMMENT ON COLUMN public.modules.course_id IS 'Reference to the course this module belongs to';
COMMENT ON COLUMN public.modules.title IS 'Module title';
COMMENT ON COLUMN public.modules.description IS 'Detailed module description';
COMMENT ON COLUMN public.modules.order_index IS 'Order of modules within a course';
COMMENT ON COLUMN public.modules.available_techniques IS 'JSON array of available study techniques for this module';

-- Course Materials table comments
COMMENT ON TABLE public.course_materials IS 'Store PDF uploads and documents for course modules';
COMMENT ON COLUMN public.course_materials.id IS 'Primary key for the course material';
COMMENT ON COLUMN public.course_materials.module_id IS 'Reference to the module this material belongs to';
COMMENT ON COLUMN public.course_materials.title IS 'Display title for the material';
COMMENT ON COLUMN public.course_materials.description IS 'Optional description of the material content';
COMMENT ON COLUMN public.course_materials.file_url IS 'Supabase Storage URL for the uploaded file';
COMMENT ON COLUMN public.course_materials.file_type IS 'File type (pdf, doc, docx, txt)';
COMMENT ON COLUMN public.course_materials.file_size IS 'File size in bytes';
COMMENT ON COLUMN public.course_materials.file_name IS 'Original filename when uploaded';
COMMENT ON COLUMN public.course_materials.order_index IS 'Order of materials within a module';
COMMENT ON COLUMN public.course_materials.created_by IS 'User who uploaded the material (instructor)';

-- Quizzes table comments
COMMENT ON TABLE public.quizzes IS 'Store AI-generated and manual quizzes for course modules';
COMMENT ON COLUMN public.quizzes.id IS 'Primary key for the quiz';
COMMENT ON COLUMN public.quizzes.module_id IS 'Reference to the module this quiz belongs to';
COMMENT ON COLUMN public.quizzes.title IS 'Quiz title';
COMMENT ON COLUMN public.quizzes.description IS 'Optional quiz description';
COMMENT ON COLUMN public.quizzes.questions IS 'Quiz questions stored as JSON array';
COMMENT ON COLUMN public.quizzes.time_limit IS 'Time limit for quiz completion in minutes';
COMMENT ON COLUMN public.quizzes.passing_score IS 'Minimum score percentage to pass';
COMMENT ON COLUMN public.quizzes.ai_generated IS 'Whether quiz was generated by AI';
COMMENT ON COLUMN public.quizzes.study_technique IS 'Study technique used for quiz generation';
COMMENT ON COLUMN public.quizzes.source_material_id IS 'PDF material used for AI generation';
COMMENT ON COLUMN public.quizzes.status IS 'Quiz status (draft, published, archived)';
COMMENT ON COLUMN public.quizzes.created_by IS 'User who created the quiz (instructor)';

-- Quiz Attempts table comments
COMMENT ON TABLE public.quiz_attempts IS 'Track student quiz attempts and performance';
COMMENT ON COLUMN public.quiz_attempts.id IS 'Primary key for the quiz attempt';
COMMENT ON COLUMN public.quiz_attempts.quiz_id IS 'Reference to the quiz taken';
COMMENT ON COLUMN public.quiz_attempts.user_id IS 'Student who took the quiz';
COMMENT ON COLUMN public.quiz_attempts.answers IS 'Student answers stored as JSON';
COMMENT ON COLUMN public.quiz_attempts.score IS 'Score achieved as percentage (0-100)';
COMMENT ON COLUMN public.quiz_attempts.completed IS 'Whether the attempt was completed';
COMMENT ON COLUMN public.quiz_attempts.time_taken IS 'Time taken to complete quiz in seconds';
COMMENT ON COLUMN public.quiz_attempts.study_technique_used IS 'Study technique used during attempt';

-- Progress tracking table comments
COMMENT ON TABLE public.user_progress IS 'Tracks student progress through courses';
COMMENT ON TABLE public.module_progress IS 'Tracks completion of individual modules';
COMMENT ON TABLE public.study_sessions IS 'Records of student study sessions with different techniques';

-- Function comments
COMMENT ON FUNCTION update_user_last_login(UUID) IS 'Updates user last_login timestamp when user logs in';
COMMENT ON FUNCTION handle_updated_at() IS 'Automatically updates updated_at timestamp on row changes';
COMMENT ON FUNCTION handle_new_user() IS 'Creates user profile when new auth user is created';

-- =============================================================================
-- DEPLOYMENT COMPLETE!
-- =============================================================================

SELECT 'LearnSmart database schema deployed successfully!' as status,
       'Total tables created: 9' as tables,
       'Tables: users, courses, modules, course_materials, quizzes, quiz_attempts, user_progress, module_progress, study_sessions' as table_list,
       'Total functions created: 3' as functions,
       'Total indexes created: 25' as indexes,
       'Total triggers created: 9' as triggers,
       'Instructor course management and AI quiz generation enabled' as features,
       'No sample data included - clean database initialization' as sample_data;

       