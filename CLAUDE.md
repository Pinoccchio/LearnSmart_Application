# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

LearnSmart is a multi-platform educational application with both Flutter mobile app and Next.js web components. The project consists of:

1. **Flutter Mobile App** (root directory) - Basic Flutter starter app
2. **Next.js Web Application** (`nextjs_web/learnsmart_web/`) - Full-featured educational platform with Supabase backend

## Common Development Commands

### Flutter Mobile App
```bash
# Install dependencies
flutter pub get

# Run the app
flutter run

# Build for Android
flutter build apk

# Build for iOS
flutter build ios

# Run tests
flutter test

# Analyze code
flutter analyze
```

### Next.js Web Application
```bash
# Change to web directory
cd nextjs_web/learnsmart_web

# Install dependencies
npm install

# Development server with Turbopack
npm run dev

# Build for production
npm run build

# Start production server
npm run start

# Lint code
npm run lint
```

## Architecture Overview

### Flutter App Structure
- Educational mobile application with multiple study techniques
- Standard Flutter project structure with `lib/main.dart` as entry point
- Uses Material Design with custom theme
- Implements comprehensive study analytics and AI-powered learning

### Next.js Web Application Architecture
- **App Router**: Next.js 15 with App Router for routing
- **Authentication**: Supabase Auth with role-based access (admin/instructor/student)
- **Database**: Supabase PostgreSQL with typed schema
- **AI Integration**: Google Gemini AI for quiz generation
- **Styling**: Tailwind CSS with Radix UI components
- **State Management**: React Context for auth and theme

#### Key Directories
- `src/app/` - App Router pages with route groups for auth and dashboard
- `src/components/` - Reusable UI components organized by feature
- `src/lib/` - Utilities, Supabase client, database types, and AI integration
- `src/contexts/` - React contexts for global state

#### Database Schema
The application uses Supabase with the following key tables:
- `profiles` - User profiles with role-based access
- `courses` - Course management
- `modules` - Course modules with materials
- `quizzes` - AI-generated quizzes with multiple techniques

#### Role-Based Access
- **Admin**: Full system access, user management, course oversight
- **Instructor**: Course creation, student management, content upload
- **Student**: Course enrollment, quiz taking, progress tracking

## Technology Stack

### Flutter App
- Flutter SDK ^3.8.1
- Dart
- Material Design

### Next.js Web App
- Next.js 15.4.6 with Turbopack
- React 19.1.0
- TypeScript 5
- Tailwind CSS 3.4.17
- Supabase 2.55.0
- Google Generative AI 0.24.1
- Radix UI components
- React Hook Form with Zod validation

## Development Workflow

1. **Web Development**: Primary development happens in `nextjs_web/learnsmart_web/`
2. **Flutter Development**: Mobile app development in root directory
3. **Database Changes**: SQL migration files are in web directory root
4. **Environment Setup**: Requires Supabase project setup for web app

## Important Files

### Configuration Files
- `nextjs_web/learnsmart_web/next.config.mjs` - Next.js configuration
- `nextjs_web/learnsmart_web/tailwind.config.ts` - Tailwind CSS config
- `nextjs_web/learnsmart_web/tsconfig.json` - TypeScript configuration
- `pubspec.yaml` - Flutter dependencies

### Key Implementation Files
- `nextjs_web/learnsmart_web/src/lib/supabase.ts` - Supabase client setup
- `nextjs_web/learnsmart_web/src/lib/gemini-ai.ts` - AI integration
- `nextjs_web/learnsmart_web/src/contexts/auth-context.tsx` - Authentication state
- `nextjs_web/learnsmart_web/src/lib/database.types.ts` - Database type definitions

### SQL Schema Files
- `nextjs_web/learnsmart_web/complete-schema.sql` - Complete database schema
- Various SQL files for specific features and fixes

### Flutter Study Techniques Implementation
The Flutter app implements four comprehensive study techniques:

#### 1. Active Recall
- **Purpose**: Test knowledge retrieval from memory using flashcards
- **Implementation**: AI-generated flashcards with multiple question types
- **Database**: `active_recall_sessions`, `active_recall_attempts` tables
- **Analytics**: Performance tracking, learning pattern analysis
- **Key Features**: Spaced repetition, difficulty adjustment, hint system

#### 2. Pomodoro Technique  
- **Purpose**: Time-based focused study sessions with breaks
- **Implementation**: Customizable work/break intervals with focus tracking
- **Database**: `pomodoro_sessions` with detailed cycle tracking
- **Analytics**: Focus score analysis, productivity metrics, session optimization
- **Key Features**: Focus scoring, break management, interruption tracking

#### 3. Feynman Technique
- **Purpose**: Learn by teaching - explain concepts in simple terms
- **Implementation**: AI-powered explanation analysis and feedback
- **Database**: `feynman_sessions` with explanation tracking
- **Analytics**: Explanation quality assessment, concept mastery analysis
- **Key Features**: Iterative explanation improvement, AI feedback, concept gaps identification

#### 4. Retrieval Practice
- **Purpose**: Strengthen memory through varied question formats and spaced repetition
- **Implementation**: AI-generated diverse question types with spaced repetition algorithm
- **Database**: `retrieval_practice_sessions`, `retrieval_practice_questions`, `retrieval_practice_attempts`, `retrieval_practice_schedules` tables
- **Analytics**: Question type performance, memory retention analysis, spaced repetition optimization
- **Key Features**: 
  - Multiple question formats (MCQ, short answer, fill-in-blank, true/false)
  - SM-2 spaced repetition algorithm implementation
  - Concept-based scheduling and review intervals
  - Performance tracking by question type and difficulty
  - Adaptive difficulty progression

### Study Analytics System
- **Comprehensive Analytics**: Descriptive and prescriptive analytics for all study techniques
- **AI Integration**: Gemini AI for content analysis and personalized recommendations
- **Database**: `study_session_analytics` table for cross-technique analysis
- **Performance Metrics**: Accuracy, response time, improvement tracking
- **Learning Patterns**: Pattern recognition, cognitive analysis, behavioral insights
- **Personalized Recommendations**: AI-generated study plans and technique suggestions

### Database Schema Overview
The application uses comprehensive database schemas for each study technique:
- **Sessions Tables**: Track user study sessions with status, duration, and settings
- **Attempts/Questions Tables**: Store detailed interaction data for analysis
- **Analytics Tables**: Comprehensive analytics data with AI-generated insights
- **Schedules Tables**: Spaced repetition scheduling (for Retrieval Practice)
- **RLS Policies**: Row-level security ensuring users only access their own data

## Development Notes

- The Flutter app implements a complete educational platform with advanced study techniques
- Each study technique follows consistent patterns: Service → UI → Analytics → AI Integration
- The Next.js web app serves as the admin/instructor platform for content management
- Supabase handles authentication, database, file storage, and real-time features
- Gemini AI provides content generation, question creation, and analytics insights
- Environment variables are required for Supabase connection and AI API keys
- The application supports comprehensive learning analytics with both descriptive and prescriptive insights
- Material upload and AI-powered question generation work across all study techniques
- Spaced repetition algorithm (SM-2) implemented for optimal learning retention