# LearnSmart Onboarding & Pre-Assessment Implementation Plan

## Analysis Summary

### Codebase Structure
- **Flutter App**: Well-organized with providers, services, screens, models
- **Auth Flow**: SplashScreen → LoginScreen/SignupScreen → MainScreen
- **Course System**: Users enroll in courses (6 available: Law Enforcement Admin, Criminology, Criminalistics, etc.)
- **Database**: 27 tables with comprehensive user progress tracking

### Current Database Schema
- **users table**: Has id, name, email, role (student/instructor/admin)
- **courses table**: 6 courses available (Law Enforcement Administration, Criminology, etc.)
- **course_enrollments table**: Tracks user course enrollment status

### Revision Materials Found
1. **Onboarding Questionnaires** (`Onboarding-Questionnaires.md`):
   - 20 questions assessing 4 learning techniques (Active Recall, Pomodoro, Feynman, Retrieval Practice)
   - 5-point Likert scale (Strongly Disagree to Strongly Agree)
   - Includes reverse-coded items for validation
   - Purpose: Identify user's learning style preferences

2. **Pre-Assessment Tests** (6 course-specific files):
   - Law Enforcement Administration: 5 modules, 30 questions each (150 total)
   - Criminology: 5 modules, 30 questions each
   - Correctional Administration: 3 modules, 30 questions each
   - And 3 more courses
   - Multiple choice format with correct answers marked
   - Course-specific content to assess baseline knowledge

---

## Implementation Plan

### Phase 1: Database Schema Changes

**New Tables to Create:**

1. **`user_onboarding_responses`**
   ```sql
   - id (uuid, primary key)
   - user_id (uuid, foreign key → users)
   - question_number (int, 1-20)
   - technique_category (text: active_recall, pomodoro, feynman, retrieval_practice)
   - response_value (int, 1-5)
   - is_reverse_coded (boolean)
   - created_at (timestamp)
   ```

2. **`user_onboarding_results`**
   ```sql
   - id (uuid, primary key)
   - user_id (uuid, foreign key → users, unique)
   - active_recall_score (int, 0-25)
   - pomodoro_score (int, 0-25)
   - feynman_score (int, 0-25)
   - retrieval_practice_score (int, 0-25)
   - top_technique (text)
   - completed_at (timestamp)
   - created_at (timestamp)
   ```

3. **`course_pre_assessment_questions`**
   ```sql
   - id (uuid, primary key)
   - course_id (uuid, foreign key → courses)
   - module_name (text, e.g., "Module 1: Law Enforcement Management")
   - question_number (int)
   - question_text (text)
   - option_a (text)
   - option_b (text)
   - option_c (text)
   - option_d (text)
   - correct_answer (text: A, B, C, or D)
   - created_at (timestamp)
   ```

4. **`user_pre_assessment_attempts`**
   ```sql
   - id (uuid, primary key)
   - user_id (uuid, foreign key → users)
   - course_id (uuid, foreign key → courses)
   - question_id (uuid, foreign key → course_pre_assessment_questions)
   - selected_answer (text: A, B, C, or D)
   - is_correct (boolean)
   - completed_at (timestamp)
   - created_at (timestamp)
   ```

5. **`user_pre_assessment_results`**
   ```sql
   - id (uuid, primary key)
   - user_id (uuid, foreign key → users)
   - course_id (uuid, foreign key → courses)
   - total_questions (int)
   - correct_answers (int)
   - score_percentage (float)
   - weak_modules (jsonb, array of module names)
   - completed_at (timestamp)
   - created_at (timestamp)
   ```

**Modify Existing Tables:**

6. **`users` table** - Add columns:
   ```sql
   - onboarding_completed (boolean, default: false)
   - onboarding_completed_at (timestamp, nullable)
   ```

7. **`course_enrollments` table** - Add columns:
   ```sql
   - pre_assessment_completed (boolean, default: false)
   - pre_assessment_score (float, nullable)
   - pre_assessment_completed_at (timestamp, nullable)
   ```

---

### Phase 2: Flutter App Implementation

**2.1 Create New Models:**

1. **`lib/models/onboarding_models.dart`**:
   - `OnboardingQuestion`
   - `OnboardingResponse`
   - `OnboardingResults`
   - `TechniqueScore`

2. **`lib/models/pre_assessment_models.dart`**:
   - `PreAssessmentQuestion`
   - `PreAssessmentAttempt`
   - `PreAssessmentResults`

**2.2 Create New Services:**

1. **`lib/services/onboarding_service.dart`**:
   - `getOnboardingQuestions()` - Load 20 questions
   - `submitOnboardingResponse(userId, questionNumber, value)`
   - `calculateOnboardingResults(userId)` - Calculate scores for all 4 techniques
   - `getOnboardingResults(userId)`

2. **`lib/services/pre_assessment_service.dart`**:
   - `getPreAssessmentQuestions(courseId)` - Load course-specific questions
   - `submitPreAssessmentAnswer(userId, courseId, questionId, answer)`
   - `calculatePreAssessmentResults(userId, courseId)`
   - `getPreAssessmentResults(userId, courseId)`

**2.3 Create New Screens:**

1. **`lib/screens/onboarding/onboarding_welcome_screen.dart`**:
   - Welcome message explaining the onboarding process
   - "Start Assessment" button

2. **`lib/screens/onboarding/onboarding_questionnaire_screen.dart`**:
   - Display 20 questions one at a time or in sections
   - 5-point Likert scale radio buttons for each question
   - Progress indicator
   - "Next" and "Previous" navigation
   - "Submit" button on final question

3. **`lib/screens/onboarding/onboarding_results_screen.dart`**:
   - Display scores for all 4 techniques
   - Visual representation (bar chart or radar chart)
   - Highlight top technique
   - Explanation of what each technique means
   - "Continue to App" button

4. **`lib/screens/pre_assessment/pre_assessment_intro_screen.dart`**:
   - Course-specific introduction
   - Explain the purpose of pre-assessment
   - "Start Pre-Assessment" button
   - "Skip" option (if allowed)

5. **`lib/screens/pre_assessment/pre_assessment_quiz_screen.dart`**:
   - Display questions one at a time
   - Multiple choice (A, B, C, D) radio buttons
   - Progress indicator (e.g., "Question 5 of 150")
   - "Next" button, "Previous" button
   - "Submit" button on final question

6. **`lib/screens/pre_assessment/pre_assessment_results_screen.dart`**:
   - Display total score and percentage
   - Module-by-module breakdown
   - Identify weak areas
   - Recommendations for study focus
   - "Continue to Course" button

**2.4 Modify Existing Screens:**

1. **`lib/screens/splash_screen.dart`**:
   - After auth check, check if `onboarding_completed` is false
   - If false, navigate to OnboardingWelcomeScreen instead of MainScreen

2. **`lib/screens/course_catalog/course_catalog_screen.dart`**:
   - After enrollment, check if pre-assessment is required
   - Navigate to PreAssessmentIntroScreen

3. **`lib/screens/modules/course_overview_screen.dart`**:
   - Show pre-assessment results if available
   - Display weak modules with recommendations

---

### Phase 3: Integration Strategy

**Onboarding Flow:**
```
SignupScreen → SplashScreen → [Check onboarding_completed]
  → If FALSE: OnboardingWelcomeScreen → OnboardingQuestionnaireScreen → OnboardingResultsScreen → MainScreen
  → If TRUE: MainScreen
```

**Pre-Assessment Flow:**
```
CourseCatalogScreen → [Enroll in Course] → PreAssessmentIntroScreen → PreAssessmentQuizScreen → PreAssessmentResultsScreen → CourseOverviewScreen
```

**Key Features:**
1. **One-time Onboarding**: Runs only once after signup
2. **Course-specific Pre-Assessment**: Runs once per course enrollment
3. **Skip Option**: Allow users to skip pre-assessment (mark as completed with 0 score)
4. **Results Persistence**: Store results in database for future reference
5. **Adaptive Recommendations**: Use onboarding results to suggest study techniques

---

### Phase 4: Data Migration

**Seed Pre-Assessment Questions:**
- Parse all 6 pre-test markdown files
- Extract questions, options, and correct answers
- Insert into `course_pre_assessment_questions` table
- Map to correct course_id based on course title

**Onboarding Questions:**
- Hard-code the 20 onboarding questions in the app
- OR store in database with a `onboarding_questions` table

---

## Implementation Order

1. ✅ **Analyze codebase and materials** (COMPLETED)
2. **Create database schema changes** (SQL migration scripts)
3. **Seed pre-assessment questions** (Data import script)
4. **Build onboarding models and services**
5. **Build pre-assessment models and services**
6. **Create onboarding screens**
7. **Create pre-assessment screens**
8. **Integrate onboarding into signup flow**
9. **Integrate pre-assessment into course enrollment flow**
10. **Testing and refinement**

---

## Notes

- **Onboarding Questions**: Stored in `REVISION/Onboarding-Questionnaires.md` - 20 questions assessing learning style preferences
- **Pre-Assessment Questions**: Stored in 6 markdown files - Course-specific questions to assess baseline knowledge
- **Users Table Modification**: Need to add `onboarding_completed` flag
- **Course Enrollments**: Need to add `pre_assessment_completed` flag and score
- **UI/UX**: Use existing app theme (AppColors, Lucide Icons) for consistency

Ready to proceed with implementation?