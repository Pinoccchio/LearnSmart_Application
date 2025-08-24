-- =============================================================================
-- LearnSmart Fresh Quiz Table with Multi-Technique Support (FIXED)
-- =============================================================================
-- Copy and paste this entire file into Supabase SQL Editor and run it
-- This will recreate the quizzes table with proper multi-technique support
-- 
-- SAFE TO RUN: Only affects the quizzes table (which is empty)
-- FIXED: Removed subquery constraint that caused PostgreSQL error
-- =============================================================================

-- Start transaction for safety
BEGIN;

-- =============================================================================
-- 1. DROP AND RECREATE QUIZZES TABLE WITH MULTI-TECHNIQUE SUPPORT
-- =============================================================================

-- Drop the existing quizzes table (safe since it's empty)
DROP TABLE IF EXISTS public.quizzes CASCADE;

-- Create new quizzes table with JSONB study_techniques from the start
CREATE TABLE public.quizzes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  module_id UUID REFERENCES public.modules(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  questions JSONB NOT NULL, -- Store quiz questions as JSON array
  time_limit INTEGER, -- Time limit in minutes (optional)
  passing_score INTEGER DEFAULT 70, -- Passing score percentage
  ai_generated BOOLEAN DEFAULT false, -- Whether quiz was AI-generated
  study_techniques JSONB DEFAULT '["general"]'::jsonb, -- Array of study techniques used for generation
  source_material_id UUID REFERENCES public.course_materials(id), -- Link to PDF used for generation
  status TEXT DEFAULT 'draft', -- 'draft', 'published', 'archived'
  created_by UUID REFERENCES public.users(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =============================================================================
-- 2. ADD SIMPLE CONSTRAINTS (NO SUBQUERIES)
-- =============================================================================

-- Ensure study_techniques is always a valid JSON array
ALTER TABLE public.quizzes 
ADD CONSTRAINT chk_study_techniques_is_array 
CHECK (jsonb_typeof(study_techniques) = 'array');

-- Ensure array is not empty
ALTER TABLE public.quizzes 
ADD CONSTRAINT chk_study_techniques_not_empty 
CHECK (jsonb_array_length(study_techniques) > 0);

-- Ensure status is valid
ALTER TABLE public.quizzes 
ADD CONSTRAINT chk_quiz_status 
CHECK (status IN ('draft', 'published', 'archived'));

-- =============================================================================
-- 3. CREATE OPTIMIZED INDEXES FOR PERFORMANCE
-- =============================================================================

-- Primary indexes for common queries
CREATE INDEX idx_quizzes_module ON public.quizzes(module_id);
CREATE INDEX idx_quizzes_created_by ON public.quizzes(created_by);
CREATE INDEX idx_quizzes_source_material ON public.quizzes(source_material_id);
CREATE INDEX idx_quizzes_status ON public.quizzes(status);
CREATE INDEX idx_quizzes_ai_generated ON public.quizzes(ai_generated);

-- Specialized JSONB indexes for multi-technique queries
CREATE INDEX idx_quizzes_study_techniques_gin 
ON public.quizzes USING GIN (study_techniques);

CREATE INDEX idx_quizzes_techniques_contains 
ON public.quizzes USING GIN (study_techniques jsonb_path_ops);

-- =============================================================================
-- 4. CREATE VALIDATION FUNCTION FOR TECHNIQUE VALUES
-- =============================================================================

-- Function to validate study technique values (replaces the problematic constraint)
CREATE OR REPLACE FUNCTION validate_study_techniques(techniques JSONB)
RETURNS BOOLEAN AS $$
DECLARE
  technique TEXT;
  valid_techniques TEXT[] := ARRAY['general', 'active_recall', 'feynman', 'retrieval_practice', 'pomodoro'];
BEGIN
  -- Check if it's an array
  IF jsonb_typeof(techniques) != 'array' THEN
    RETURN FALSE;
  END IF;
  
  -- Check if array is empty
  IF jsonb_array_length(techniques) = 0 THEN
    RETURN FALSE;
  END IF;
  
  -- Check each technique value
  FOR technique IN SELECT jsonb_array_elements_text(techniques) LOOP
    IF NOT (technique = ANY(valid_techniques)) THEN
      RETURN FALSE;
    END IF;
  END LOOP;
  
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- =============================================================================
-- 5. CREATE HELPER FUNCTIONS FOR QUERYING
-- =============================================================================

-- Function to check if quiz uses specific technique
CREATE OR REPLACE FUNCTION quiz_uses_technique(techniques JSONB, technique_name TEXT)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN techniques ? technique_name;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Function to get technique names as text array
CREATE OR REPLACE FUNCTION get_technique_names(techniques JSONB)
RETURNS TEXT[] AS $$
BEGIN
  RETURN ARRAY(SELECT jsonb_array_elements_text(techniques));
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Function to format techniques for display
CREATE OR REPLACE FUNCTION format_techniques_display(techniques JSONB)
RETURNS TEXT AS $$
BEGIN
  RETURN array_to_string(
    ARRAY(
      SELECT CASE jsonb_array_elements_text(techniques)
        WHEN 'general' THEN 'General Review'
        WHEN 'active_recall' THEN 'Active Recall'
        WHEN 'feynman' THEN 'Feynman Technique'
        WHEN 'retrieval_practice' THEN 'Retrieval Practice'
        WHEN 'pomodoro' THEN 'Pomodoro Session'
        ELSE jsonb_array_elements_text(techniques)
      END
    ), 
    ', '
  );
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Function to count techniques in a quiz
CREATE OR REPLACE FUNCTION count_techniques(techniques JSONB)
RETURNS INTEGER AS $$
BEGIN
  RETURN jsonb_array_length(techniques);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- =============================================================================
-- 6. ADD UPDATED_AT TRIGGER
-- =============================================================================

-- Add trigger to automatically update updated_at timestamp
CREATE TRIGGER set_updated_at_quizzes 
BEFORE UPDATE ON public.quizzes 
FOR EACH ROW EXECUTE FUNCTION handle_updated_at();

-- =============================================================================
-- 7. GRANT PERMISSIONS
-- =============================================================================

-- Grant permissions to authenticated users
GRANT ALL ON public.quizzes TO authenticated;
GRANT EXECUTE ON FUNCTION validate_study_techniques(JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION quiz_uses_technique(JSONB, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_technique_names(JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION format_techniques_display(JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION count_techniques(JSONB) TO authenticated;

-- =============================================================================
-- 8. ADD TABLE COMMENTS FOR DOCUMENTATION
-- =============================================================================

-- Table and column comments
COMMENT ON TABLE public.quizzes IS 'Store AI-generated and manual quizzes with multi-technique support';
COMMENT ON COLUMN public.quizzes.id IS 'Primary key for the quiz';
COMMENT ON COLUMN public.quizzes.module_id IS 'Reference to the module this quiz belongs to';
COMMENT ON COLUMN public.quizzes.title IS 'Quiz title';
COMMENT ON COLUMN public.quizzes.description IS 'Optional quiz description';
COMMENT ON COLUMN public.quizzes.questions IS 'Quiz questions stored as JSON array';
COMMENT ON COLUMN public.quizzes.time_limit IS 'Time limit for quiz completion in minutes';
COMMENT ON COLUMN public.quizzes.passing_score IS 'Minimum score percentage to pass';
COMMENT ON COLUMN public.quizzes.ai_generated IS 'Whether quiz was generated by AI';
COMMENT ON COLUMN public.quizzes.study_techniques IS 'Array of study techniques used for quiz generation - JSONB format (e.g., ["general", "active_recall"])';
COMMENT ON COLUMN public.quizzes.source_material_id IS 'PDF material used for AI generation';
COMMENT ON COLUMN public.quizzes.status IS 'Quiz status (draft, published, archived)';
COMMENT ON COLUMN public.quizzes.created_by IS 'User who created the quiz (instructor)';

-- Function comments
COMMENT ON FUNCTION validate_study_techniques(JSONB) IS 'Validates that study_techniques contains only valid technique values';
COMMENT ON FUNCTION quiz_uses_technique(JSONB, TEXT) IS 'Check if quiz uses a specific study technique';
COMMENT ON FUNCTION get_technique_names(JSONB) IS 'Get technique names as text array';
COMMENT ON FUNCTION format_techniques_display(JSONB) IS 'Format techniques for human-readable display';
COMMENT ON FUNCTION count_techniques(JSONB) IS 'Count number of techniques used in quiz';

-- =============================================================================
-- 9. CREATE SAMPLE DATA (OPTIONAL - REMOVE IF NOT NEEDED)
-- =============================================================================

-- Insert a sample multi-technique quiz for testing (uncomment if you want sample data)
/*
INSERT INTO public.quizzes (
  title,
  description,
  questions,
  study_techniques,
  ai_generated,
  status
) VALUES (
  'Sample Multi-Technique Quiz',
  'Example quiz using multiple study techniques',
  '[
    {
      "id": 1,
      "type": "multiple_choice",
      "question": "What is criminal law?",
      "options": ["A body of law", "A type of court", "A legal document", "A punishment"],
      "correct_answer": 0,
      "explanation": "Criminal law is a body of law that deals with crimes and punishment.",
      "points": 5
    }
  ]'::jsonb,
  '["general", "active_recall", "feynman"]'::jsonb,
  true,
  'published'
);
*/

-- =============================================================================
-- 10. COMMIT TRANSACTION
-- =============================================================================

-- Commit all changes if everything executed successfully
COMMIT;

-- =============================================================================
-- SUCCESS MESSAGE AND VERIFICATION
-- =============================================================================

SELECT 
  '🎯 Fresh Quiz Table Created Successfully!' as status,
  'Multi-technique support enabled from the start' as feature,
  'JSONB format: ["general", "active_recall", "feynman"]' as data_format,
  'Optimized indexes created for fast queries' as performance,
  'Helper functions added for easy data manipulation' as utilities,
  'Validation function replaces problematic constraint' as constraint_fix,
  'Ready for AI quiz generation with multiple techniques!' as next_steps;

-- Show table structure verification
SELECT 
  column_name,
  data_type,
  column_default,
  is_nullable
FROM information_schema.columns 
WHERE table_schema = 'public' 
  AND table_name = 'quizzes'
  AND column_name IN ('study_techniques', 'title', 'questions')
ORDER BY column_name;

-- Show function verification
SELECT 
  routine_name,
  routine_type
FROM information_schema.routines 
WHERE routine_schema = 'public' 
  AND routine_name LIKE '%technique%'
ORDER BY routine_name;

-- =============================================================================
-- EXAMPLE USAGE QUERIES FOR YOUR REFERENCE
-- =============================================================================

-- These are example queries you can use in your application:

-- Find quizzes that use Active Recall technique:
-- SELECT * FROM quizzes WHERE quiz_uses_technique(study_techniques, 'active_recall');

-- Find quizzes using multiple techniques:
-- SELECT title, count_techniques(study_techniques) as technique_count 
-- FROM quizzes WHERE count_techniques(study_techniques) > 1;

-- Find quizzes using specific combination:
-- SELECT * FROM quizzes WHERE study_techniques ?& array['active_recall', 'feynman'];

-- Get human-readable technique display:
-- SELECT title, format_techniques_display(study_techniques) as techniques 
-- FROM quizzes;

-- Insert new multi-technique quiz:
-- INSERT INTO quizzes (title, questions, study_techniques, ai_generated)
-- VALUES ('New Quiz', '[...]'::jsonb, '["general", "pomodoro"]'::jsonb, true);

-- Validate techniques before insert (optional application-level check):
-- SELECT validate_study_techniques('["general", "active_recall"]'::jsonb);