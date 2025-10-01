# Onboarding System Implementation

## Overview
The onboarding system assesses new users' learning style preferences across 4 evidence-based techniques through a 20-question questionnaire. Results are used to personalize the learning experience.

---

## ✅ Completed Implementation

### 1. Database Schema (`database/migrations/onboarding_schema.sql`)

**Tables Created:**
- `user_onboarding_responses` - Stores individual question responses (1-5 Likert scale)
- `user_onboarding_results` - Stores calculated scores for each technique
- `users` table modifications - Added `onboarding_completed` and `onboarding_completed_at` columns

**Features:**
- Row-level security (RLS) policies ensuring users only access their own data
- Automatic `updated_at` timestamp triggers
- Check constraints for data validation
- Indexed queries for performance

### 2. Models (`lib/models/onboarding_models.dart`)

**Classes:**
- `OnboardingQuestion` - Represents a single questionnaire item
- `OnboardingResponse` - User's response to a question
- `TechniqueScore` - Individual technique score with interpretation
- `OnboardingResult` - Complete assessment results with all technique scores

**Key Methods:**
- `getTechniqueScores()` - Returns all 4 technique scores
- `getTopTechniqueScore()` - Returns the highest-scoring technique
- Score level interpretation (Strong: 20-25, Moderate: 15-19, Low: 10-14, Very Low: 5-9)

### 3. Service Layer (`lib/services/onboarding_service.dart`)

**Hardcoded Questions:**
- 20 questions loaded via `getOnboardingQuestions()`
- Questions grouped by technique (5 per technique)
- Reverse-coded items: Q4, Q7, Q12, Q20

**Database Methods:**
- `saveResponse()` - Save single response (upsert)
- `saveAllResponses()` - Batch save all 20 responses
- `calculateAndSaveResults()` - Calculate scores with reverse-coding logic
- `getUserResponses()` - Fetch user's responses
- `getUserResults()` - Fetch saved results
- `hasCompletedOnboarding()` - Check completion status
- `getResponseCount()` - Track progress

**Scoring Logic:**
- Standard scoring: value = response (1-5)
- Reverse scoring: value = 6 - response
- Each technique: Sum of 5 items (max 25 points)
- Top technique: Highest score among 4 techniques

### 4. UI Screens

#### `lib/screens/onboarding/onboarding_welcome_screen.dart`
- Gradient header with app branding
- Explains assessment purpose and duration (~5 minutes)
- Lists all 4 learning techniques with icons
- "Start Assessment" button

#### `lib/screens/onboarding/onboarding_questionnaire_screen.dart`
- Question-by-question navigation (1 of 20)
- Progress bar indicator
- Category badge for each question
- Likert scale widget (1-5)
- Previous/Next navigation
- Submit button on final question
- Auto-save responses to database
- Loading state during submission

#### `lib/screens/onboarding/onboarding_results_screen.dart`
- Success celebration UI
- Highlights top technique with badge
- Visual score cards for all 4 techniques
- Progress bars showing relative scores
- Detailed description of top technique
- Personalization message
- "Continue to App" button

### 5. Widgets

#### `lib/widgets/onboarding/likert_scale_widget.dart`
- 5-point interactive scale
- Selected state highlighting
- Labels: "Strongly Disagree" to "Strongly Agree"
- Touch-friendly design

### 6. Integration

#### Modified Files:
- `lib/models/user.dart` - Added `onboardingCompleted` and `onboardingCompletedAt` fields
- `lib/screens/splash_screen.dart` - Routes to onboarding if not completed

#### Navigation Flow:
```
SplashScreen
  → Check auth status
    → Not authenticated: LoginScreen
    → Authenticated:
      → Check onboarding_completed
        → FALSE: OnboardingWelcomeScreen → OnboardingQuestionnaireScreen → OnboardingResultsScreen → MainScreen
        → TRUE: MainScreen
```

---

## 🚀 Deployment Steps

### 1. Apply Database Migration

**Option A: Supabase SQL Editor (Recommended)**
1. Open [Supabase Dashboard](https://supabase.com/dashboard/project/gqapqhmminijctsizqpj)
2. Navigate to **SQL Editor**
3. Copy contents from `learnsmart_app/database/migrations/onboarding_schema.sql`
4. Execute the SQL

**Option B: CLI (if available)**
```bash
supabase db push
```

### 2. Verify Tables Created

Run this query to verify:
```sql
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name LIKE '%onboarding%';
```

Should return:
- `user_onboarding_responses`
- `user_onboarding_results`

### 3. Test the App

```bash
cd learnsmart_app
flutter pub get
flutter run
```

**Test Scenarios:**
1. **New User Flow:**
   - Sign up with a new account
   - Should automatically redirect to OnboardingWelcomeScreen
   - Complete all 20 questions
   - View results
   - Continue to MainScreen

2. **Returning User Flow:**
   - Sign in with an account that completed onboarding
   - Should go directly to MainScreen

3. **Data Persistence:**
   - Complete onboarding partially
   - Close app
   - Reopen app
   - Should resume from last answered question

---

## 📊 Database Schema Details

### user_onboarding_responses
```sql
- id: UUID (PK)
- user_id: UUID (FK → users)
- question_number: INTEGER (1-20)
- technique_category: TEXT (active_recall, pomodoro, feynman, retrieval_practice)
- response_value: INTEGER (1-5)
- is_reverse_coded: BOOLEAN
- created_at: TIMESTAMPTZ
- updated_at: TIMESTAMPTZ

UNIQUE(user_id, question_number)
```

### user_onboarding_results
```sql
- id: UUID (PK)
- user_id: UUID (FK → users, UNIQUE)
- active_recall_score: INTEGER (0-25)
- pomodoro_score: INTEGER (0-25)
- feynman_score: INTEGER (0-25)
- retrieval_practice_score: INTEGER (0-25)
- top_technique: TEXT
- completed_at: TIMESTAMPTZ
- created_at: TIMESTAMPTZ
- updated_at: TIMESTAMPTZ
```

### users (modifications)
```sql
+ onboarding_completed: BOOLEAN DEFAULT FALSE
+ onboarding_completed_at: TIMESTAMPTZ
```

---

## 🎨 UI Design Features

- **Color Coding by Technique:**
  - Active Recall: Purple (#8B5CF6)
  - Pomodoro: Red (#EF4444)
  - Feynman: Green (#10B981)
  - Retrieval Practice: Orange (#F59E0B)

- **Consistent with App Theme:**
  - Uses `AppColors` constants
  - Material Design components
  - Gradient backgrounds
  - Rounded corners and shadows
  - Responsive layouts

---

## 📝 Assessment Questions

### Active Recall (Questions 1-5)
1. I prefer to close my notes and try to recall key concepts after studying a topic.
2. I try to write down everything I remember after studying a topic without looking at my notes.
3. I prefer reciting important ideas aloud without checking my materials.
4. **I usually just reread my notes instead of trying to recall the information from memory.** *(reverse)*
5. I cover key points in my notes and attempt to recall them from memory.

### Pomodoro Technique (Questions 6-10)
6. I focus better when I study in short, timed intervals with scheduled breaks.
7. **I prefer studying continuously for long periods without taking short breaks.** *(reverse)*
8. I lose focus if I study for long periods without taking breaks.
9. I find it easier to concentrate when I use a timer to structure my study time.
10. I feel more productive when I follow a fixed cycle of study and rest.

### Feynman Technique (Questions 11-15)
11. I learn best when I try to explain the topic as if I were teaching someone else.
12. **I rarely try to explain topics in my own words because it doesn't help me understand better.** *(reverse)*
13. I find it helpful to identify parts of a topic that I can't explain simply.
14. I often use simple, everyday examples to explain complex topics.
15. I feel more confident with a topic after I've explained it aloud or in writing.

### Retrieval Practice (Questions 16-20)
16. I regularly quiz myself on lessons to check how much I remember.
17. I use flashcards to test what I have studied.
18. I revisit topics after several days to strengthen what I learned.
19. I remember information better when I test myself multiple times.
20. **I find that practice tests are not useful for remembering what I studied.** *(reverse)*

---

## 🔒 Security Considerations

- **Row-Level Security (RLS):** All onboarding tables have RLS enabled
- **User Isolation:** Users can only access their own responses and results
- **Data Validation:** Check constraints prevent invalid values
- **Auth Integration:** Uses Supabase Auth for user identification

---

## 🧪 Testing Checklist

- [ ] Database migration applied successfully
- [ ] New user redirected to onboarding
- [ ] All 20 questions display correctly
- [ ] Likert scale interaction works
- [ ] Previous/Next navigation works
- [ ] Cannot proceed without answering
- [ ] Responses saved to database
- [ ] Scores calculated correctly (including reverse-coding)
- [ ] Results screen displays properly
- [ ] Continue button navigates to MainScreen
- [ ] Returning users skip onboarding
- [ ] RLS policies prevent unauthorized access

---

## 📈 Future Enhancements

1. **Analytics Dashboard:**
   - Aggregate onboarding results across all users
   - Identify common learning style patterns

2. **Adaptive Recommendations:**
   - Suggest study techniques based on results
   - Personalize course recommendations

3. **Re-assessment:**
   - Allow users to retake assessment
   - Track changes in learning preferences over time

4. **Technique-Specific Features:**
   - Customize UI based on top technique
   - Unlock features aligned with user's style

5. **Multi-language Support:**
   - Translate questions and results
   - Localized descriptions

---

## 🐛 Troubleshooting

### Issue: "Table doesn't exist" error
**Solution:** Ensure database migration was applied successfully

### Issue: User not redirected to onboarding
**Solution:** Check that `onboarding_completed` field exists in users table and is FALSE for new users

### Issue: Scores not calculating correctly
**Solution:** Verify reverse-coding logic for questions 4, 7, 12, 20

### Issue: Cannot submit responses
**Solution:** Check Supabase RLS policies and ensure user is authenticated

---

## 📚 References

- **Active Recall:** Karpicke & Roediger (2008) - "The Critical Importance of Retrieval for Learning"
- **Pomodoro Technique:** Francesco Cirillo - "The Pomodoro Technique"
- **Feynman Technique:** Richard Feynman - Learning by teaching
- **Retrieval Practice:** Roediger & Butler (2011) - "The critical role of retrieval practice"

---

## 👤 Implementation Notes

- **Developer:** Claude Code
- **Date:** 2025
- **Version:** 1.0
- **Status:** ✅ Ready for Testing

All core onboarding features are implemented and ready for deployment!
