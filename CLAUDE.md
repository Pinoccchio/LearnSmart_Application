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
- Basic Flutter starter template with minimal customization
- Standard Flutter project structure with `lib/main.dart` as entry point
- Uses Material Design with default theme

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

## Development Notes

- The Flutter app is currently a basic template and can be extended for mobile functionality
- The Next.js web app is the primary application with full CRUD operations
- Supabase handles authentication, database, and file storage
- Environment variables are required for Supabase connection
- The application supports dark/light theme switching
- Material upload and quiz generation features use AI integration