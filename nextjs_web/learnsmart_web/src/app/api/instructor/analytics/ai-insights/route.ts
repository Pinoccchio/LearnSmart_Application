import { NextRequest, NextResponse } from 'next/server'
import { supabase } from '@/lib/supabase'
import { teachingAnalyticsAI } from '@/lib/teaching-analytics-ai'
import type { CourseAnalyticsData, StudentPerformanceData } from '@/lib/teaching-analytics-ai'

export async function GET(request: NextRequest) {
  try {
    console.log('🤖 [AI INSIGHTS] AI-powered teaching insights API called')
    
    // Authentication
    const authHeader = request.headers.get('Authorization')
    let user = null
    let userId = null
    
    if (authHeader && authHeader.startsWith('Bearer ')) {
      try {
        const token = authHeader.replace('Bearer ', '')
        const { data: { user: tokenUser }, error: authError } = await supabase.auth.getUser(token)
        if (!authError && tokenUser) {
          user = tokenUser
          userId = tokenUser.id
        }
      } catch (error) {
        console.log('⚠️ Token auth failed, trying alternative auth')
      }
    }
    
    if (!user) {
      userId = request.headers.get('X-User-ID')
      if (!userId) {
        return NextResponse.json({ error: 'Authentication required' }, { status: 401 })
      }
      user = { id: userId }
    }

    // Verify user is an instructor
    const { data: userProfile, error: profileError } = await supabase
      .from('users')
      .select('role, id, name')
      .eq('id', userId)
      .single()

    if (profileError || !userProfile || userProfile.role !== 'instructor') {
      return NextResponse.json(
        { error: 'Access denied. Instructor role required.' },
        { status: 403 }
      )
    }

    // Get query parameters
    const { searchParams } = new URL(request.url)
    const timeRange = searchParams.get('timeRange') || 'month'
    const courseId = searchParams.get('courseId') // Optional: specific course analysis
    
    // Calculate date filter
    const now = new Date()
    let startDate = new Date()
    switch (timeRange) {
      case 'week':
        startDate.setDate(now.getDate() - 7)
        break
      case 'month':
        startDate.setMonth(now.getMonth() - 1)
        break
      case 'quarter':
        startDate.setMonth(now.getMonth() - 3)
        break
      default:
        startDate.setMonth(now.getMonth() - 1)
    }

    console.log('🔍 [AI INSIGHTS] Collecting data for AI analysis...')

    // Get instructor's courses (or specific course)
    let coursesQuery = supabase
      .from('courses')
      .select('id, title, description, created_at')
      .eq('instructor_id', userProfile.id)

    if (courseId) {
      coursesQuery = coursesQuery.eq('id', courseId)
    }

    const { data: courses, error: coursesError } = await coursesQuery
    
    if (coursesError || !courses || courses.length === 0) {
      return NextResponse.json({
        success: true,
        data: {
          insights: [],
          recommendations: [],
          aiStatus: 'no_data',
          message: 'No course data available for analysis'
        }
      })
    }

    const courseIds = courses.map(c => c.id)

    // Get comprehensive student performance data
    const { data: enrollments, error: enrollmentsError } = await supabase
      .from('course_enrollments')
      .select(`
        user_id,
        course_id,
        enrolled_at,
        status,
        users(id, name, email),
        courses(id, title)
      `)
      .in('course_id', courseIds)
      .eq('status', 'active')

    if (enrollmentsError) {
      console.error('❌ Error fetching enrollments:', enrollmentsError)
      return NextResponse.json({ error: 'Failed to fetch student data' }, { status: 500 })
    }

    const studentIds = enrollments.map(e => e.user_id)

    // Gather all analytics data for AI processing
    const [studyAnalytics, moduleProgress, studySessions] = await Promise.all([
      // Study session analytics
      supabase
        .from('study_session_analytics')
        .select('*')
        .in('user_id', studentIds)
        .gte('created_at', startDate.toISOString()),
      
      // Module progress
      supabase
        .from('user_module_progress')
        .select(`
          *,
          modules(id, title, course_id, difficulty_level),
          users(id, name)
        `)
        .in('user_id', studentIds),
      
      // Recent study sessions from all technique tables
      Promise.all([
        supabase.from('active_recall_sessions').select('*').in('user_id', studentIds).gte('created_at', startDate.toISOString()),
        supabase.from('pomodoro_sessions').select('*').in('user_id', studentIds).gte('created_at', startDate.toISOString()),
        supabase.from('feynman_sessions').select('*').in('user_id', studentIds).gte('created_at', startDate.toISOString()),
        supabase.from('retrieval_practice_sessions').select('*').in('user_id', studentIds).gte('created_at', startDate.toISOString())
      ]).then(results => {
        const allSessions = []
        const types = ['active_recall', 'pomodoro', 'feynman', 'retrieval_practice']
        
        results.forEach((result, index) => {
          if (result.data) {
            allSessions.push(...result.data.map(session => ({
              ...session,
              session_type: types[index]
            })))
          }
        })
        
        return { data: allSessions }
      })
    ])

    console.log('📊 [AI INSIGHTS] Processing data for AI analysis...')

    // Process data for AI analysis
    const courseAnalyticsData: CourseAnalyticsData[] = courses.map(course => {
      const courseEnrollments = enrollments.filter(e => e.course_id === course.id)
      const courseStudentIds = courseEnrollments.map(e => e.user_id)
      
      // Filter data for this course
      const courseSessions = studySessions.data?.filter(s => courseStudentIds.includes(s.user_id)) || []
      const courseAnalytics = studyAnalytics.data?.filter(a => courseStudentIds.includes(a.user_id)) || []
      const courseModuleProgress = moduleProgress.data?.filter(mp => 
        mp.modules?.course_id === course.id
      ) || []

      // Calculate study technique performance
      const techniqueStats = {
        active_recall: courseSessions.filter(s => s.session_type === 'active_recall'),
        pomodoro: courseSessions.filter(s => s.session_type === 'pomodoro'),
        feynman: courseSessions.filter(s => s.session_type === 'feynman'),
        retrieval_practice: courseSessions.filter(s => s.session_type === 'retrieval_practice')
      }

      const studySessionsData = Object.entries(techniqueStats).map(([technique, sessions]) => {
        const techniqueAnalytics = courseAnalytics.filter(a => a.session_type === technique)
        const effectiveness = techniqueAnalytics.length > 0 ? 
          techniqueAnalytics.reduce((sum, a) => {
            const performance = a.performance_metrics || {}
            return sum + (performance.overall_accuracy || performance.improvement || 0)
          }, 0) / techniqueAnalytics.length : 0

        const adoptionRate = courseStudentIds.length > 0 ? 
          (new Set(sessions.map(s => s.user_id)).size / courseStudentIds.length) * 100 : 0

        return {
          technique: technique.replace('_', ' ').replace(/\b\w/g, l => l.toUpperCase()),
          totalSessions: sessions.length,
          averageEffectiveness: Math.round(effectiveness),
          adoptionRate: Math.round(adoptionRate)
        }
      })

      // Calculate module performance
      const moduleMap = new Map()
      courseModuleProgress.forEach(mp => {
        const moduleId = mp.module_id
        const moduleName = mp.modules?.title || 'Unknown Module'
        const difficulty = mp.modules?.difficulty_level || 'medium'
        
        if (!moduleMap.has(moduleId)) {
          moduleMap.set(moduleId, {
            moduleId,
            moduleName,
            difficulty,
            students: [],
            totalProgress: 0,
            totalScore: 0
          })
        }
        
        const moduleData = moduleMap.get(moduleId)
        moduleData.students.push(mp)
        moduleData.totalProgress += mp.completion_percentage || 0
      })

      const modulePerformance = Array.from(moduleMap.values()).map(module => {
        const studentCount = module.students.length
        const completionRate = studentCount > 0 ? module.totalProgress / studentCount : 0
        const strugglingCount = module.students.filter(s => (s.completion_percentage || 0) < 60).length
        
        // Calculate average score from analytics for this module
        const moduleAnalytics = courseAnalytics.filter(a => a.module_id === module.moduleId)
        const averageScore = moduleAnalytics.length > 0 ?
          moduleAnalytics.reduce((sum, a) => {
            const performance = a.performance_metrics || {}
            return sum + (performance.overall_accuracy || 0)
          }, 0) / moduleAnalytics.length : completionRate * 0.8 // Estimate

        return {
          moduleId: module.moduleId,
          moduleName: module.moduleName,
          difficulty: module.difficulty,
          completionRate: Math.round(completionRate),
          averageScore: Math.round(averageScore),
          strugglingStudents: strugglingCount
        }
      })

      // Calculate peak study hours
      const hourlyActivity = new Array(24).fill(0)
      courseSessions.forEach(session => {
        const hour = new Date(session.created_at).getHours()
        hourlyActivity[hour]++
      })

      const peakStudyHours = hourlyActivity.map((activity, hour) => ({ hour, activity }))
        .filter(h => h.activity > 0)
        .sort((a, b) => b.activity - a.activity)
        .slice(0, 3)

      // Calculate overall metrics
      const activeStudents = new Set(courseSessions.map(s => s.user_id)).size
      const averageProgress = courseModuleProgress.length > 0 ?
        courseModuleProgress.reduce((sum, mp) => sum + (mp.completion_percentage || 0), 0) / courseModuleProgress.length : 0
      const averageScore = courseAnalytics.length > 0 ?
        courseAnalytics.reduce((sum, a) => {
          const performance = a.performance_metrics || {}
          return sum + (performance.overall_accuracy || 0)
        }, 0) / courseAnalytics.length : 0

      return {
        courseId: course.id,
        courseName: course.title,
        instructorId: userProfile.id,
        totalStudents: courseEnrollments.length,
        activeStudents,
        averageProgress: Math.round(averageProgress),
        averageScore: Math.round(averageScore),
        studySessionsData,
        modulePerformance,
        timeRange,
        peakStudyHours
      }
    })

    // Prepare student performance data for interventions
    const studentPerformanceData: StudentPerformanceData[] = enrollments.map(enrollment => {
      const userId = enrollment.user_id
      const userName = enrollment.users?.name || 'Unknown Student'
      const courseId = enrollment.course_id
      const courseName = enrollment.courses?.title || 'Unknown Course'

      // Get student's module progress
      const studentModuleProgress = moduleProgress.data?.filter(mp => 
        mp.user_id === userId && mp.modules?.course_id === courseId
      ) || []

      const moduleProgressData = studentModuleProgress.map(mp => ({
        moduleId: mp.module_id,
        moduleName: mp.modules?.title || 'Unknown Module',
        completionPercentage: mp.completion_percentage || 0,
        averageScore: mp.completion_percentage || 0, // Simplified - could be enhanced with actual scores
        lastActivity: mp.updated_at || mp.created_at
      }))

      // Get student's study technique usage
      const studentSessions = studySessions.data?.filter(s => s.user_id === userId) || []
      const techniqueGroups = studentSessions.reduce((acc, session) => {
        const technique = session.session_type
        if (!acc[technique]) {
          acc[technique] = []
        }
        acc[technique].push(session)
        return acc
      }, {} as Record<string, any[]>)

      const studyTechniquesData = Object.entries(techniqueGroups).map(([technique, sessions]) => {
        const studentTechniqueAnalytics = studyAnalytics.data?.filter(a => 
          a.user_id === userId && a.session_type === technique
        ) || []
        
        const effectiveness = studentTechniqueAnalytics.length > 0 ?
          studentTechniqueAnalytics.reduce((sum, a) => {
            const performance = a.performance_metrics || {}
            return sum + (performance.overall_accuracy || 0)
          }, 0) / studentTechniqueAnalytics.length : 0

        return {
          technique: technique.replace('_', ' '),
          sessionsCount: sessions.length,
          effectiveness: Math.round(effectiveness),
          averageScore: Math.round(effectiveness)
        }
      })

      // Calculate overall metrics
      const overallProgress = moduleProgressData.length > 0 ?
        moduleProgressData.reduce((sum, m) => sum + m.completionPercentage, 0) / moduleProgressData.length : 0

      // Determine risk level
      const daysSinceLastActivity = studentSessions.length > 0 ?
        Math.floor((Date.now() - new Date(Math.max(...studentSessions.map(s => new Date(s.created_at).getTime()))).getTime()) / (1000 * 60 * 60 * 24)) : 999

      let riskLevel: 'low' | 'medium' | 'high' = 'low'
      if (overallProgress < 30 || daysSinceLastActivity > 14) {
        riskLevel = 'high'
      } else if (overallProgress < 60 || daysSinceLastActivity > 7) {
        riskLevel = 'medium'
      }

      const engagementLevel = Math.max(0, 100 - (daysSinceLastActivity * 5))
      const lastActiveDate = studentSessions.length > 0 ?
        new Date(Math.max(...studentSessions.map(s => new Date(s.created_at).getTime()))).toISOString() :
        enrollment.enrolled_at

      return {
        userId,
        userName,
        courseId,
        courseName,
        moduleProgress: moduleProgressData,
        studyTechniques: studyTechniquesData,
        overallProgress: Math.round(overallProgress),
        riskLevel,
        engagementLevel: Math.round(engagementLevel),
        lastActiveDate
      }
    })

    console.log('🤖 [AI INSIGHTS] Generating AI-powered insights...')

    // Generate AI insights for each course
    const allInsights = []
    const allRecommendations = []

    for (const courseData of courseAnalyticsData) {
      try {
        // Generate teaching insights
        const teachingInsights = await teachingAnalyticsAI.generateTeachingInsights(courseData)
        allInsights.push(...teachingInsights)

        // Generate technique analysis
        const techniqueAnalysis = await teachingAnalyticsAI.analyzeTechniqueEffectiveness(courseData)
        allInsights.push(...techniqueAnalysis.insights)
        allRecommendations.push(...techniqueAnalysis.recommendations)

      } catch (error) {
        console.error('❌ [AI INSIGHTS] Error generating insights for course:', courseData.courseName, error)
      }
    }

    // Generate student interventions
    try {
      const interventions = await teachingAnalyticsAI.generateStudentInterventions(
        studentPerformanceData.filter(s => s.riskLevel === 'high' || s.riskLevel === 'medium')
      )
      allRecommendations.push(...interventions)
    } catch (error) {
      console.error('❌ [AI INSIGHTS] Error generating interventions:', error)
    }

    // Sort insights and recommendations by priority
    allInsights.sort((a, b) => a.priority - b.priority)
    allRecommendations.sort((a, b) => a.priority - b.priority)

    console.log('✅ [AI INSIGHTS] Generated', allInsights.length, 'insights and', allRecommendations.length, 'recommendations')

    return NextResponse.json({
      success: true,
      data: {
        insights: allInsights.slice(0, 10), // Limit to top 10 insights
        recommendations: allRecommendations.slice(0, 8), // Limit to top 8 recommendations
        aiStatus: 'success',
        coursesAnalyzed: courses.length,
        studentsAnalyzed: studentPerformanceData.length,
        atRiskStudents: studentPerformanceData.filter(s => s.riskLevel === 'high').length,
        timeRange,
        generatedAt: new Date().toISOString()
      }
    })

  } catch (error) {
    console.error('❌ [AI INSIGHTS] Error in AI insights API:', error)
    return NextResponse.json(
      { 
        error: 'Internal server error',
        data: {
          insights: [],
          recommendations: [],
          aiStatus: 'error',
          message: 'AI analysis failed, but basic analytics are still available'
        }
      },
      { status: 500 }
    )
  }
}