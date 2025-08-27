import { NextRequest, NextResponse } from 'next/server'
import { supabase } from '@/lib/supabase'

export async function GET(request: NextRequest) {
  try {
    // Get user ID from headers
    const userId = request.headers.get('X-User-ID')
    if (!userId) {
      return NextResponse.json({ error: 'Authentication required' }, { status: 401 })
    }

    // Get time range
    const { searchParams } = new URL(request.url)
    const timeRange = searchParams.get('timeRange') || 'month'
    
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

    // 1. Get instructor's courses and enrolled students
    const { data: coursesWithStudents } = await supabase
      .from('courses')
      .select(`
        id,
        title,
        course_enrollments!inner (
          user_id,
          users!inner (
            id,
            name
          )
        )
      `)
      .eq('instructor_id', userId)
      .eq('course_enrollments.status', 'active')

    const courseIds = [...new Set(coursesWithStudents?.map(c => c.id) || [])]
    const studentIds = [...new Set(coursesWithStudents?.flatMap(c => 
      c.course_enrollments.map(e => e.user_id)
    ) || [])]
    
    const totalStudents = studentIds.length
    const totalCourses = courseIds.length

    // 2. Get study sessions count
    const { count: totalSessions } = await supabase
      .from('study_session_analytics')
      .select('*', { count: 'exact', head: true })
      .in('user_id', studentIds)
      .gte('created_at', startDate.toISOString())

    // 3. Get active students (last 7 days)
    const sevenDaysAgo = new Date()
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7)
    
    const { data: activeStudentsList } = await supabase
      .from('study_session_analytics')
      .select('user_id')
      .in('user_id', studentIds)
      .gte('created_at', sevenDaysAgo.toISOString())
    
    const activeStudents = new Set(activeStudentsList?.map(s => s.user_id) || []).size

    // 4. Get average performance
    const { data: performanceData } = await supabase
      .from('study_session_analytics')
      .select('performance_metrics')
      .in('user_id', studentIds)
      .gte('created_at', startDate.toISOString())
      .not('performance_metrics', 'is', null)
      .limit(100)

    let averageScore = 0
    if (performanceData && performanceData.length > 0) {
      const scores = performanceData.map(d => {
        const metrics = d.performance_metrics || {}
        return metrics.overall_accuracy || metrics.average_score || 0
      })
      averageScore = scores.reduce((a, b) => a + b, 0) / scores.length
    }

    // 5. Get study techniques summary
    const { data: techniquesSummary } = await supabase
      .from('study_session_analytics')
      .select('session_type')
      .in('user_id', studentIds)
      .gte('created_at', startDate.toISOString())

    const techniqueCounts = {}
    techniquesSummary?.forEach(s => {
      techniqueCounts[s.session_type] = (techniqueCounts[s.session_type] || 0) + 1
    })

    const studyTechniques = Object.entries(techniqueCounts).map(([type, count]) => ({
      technique: type.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase()),
      type,
      totalSessions: count,
      adoptionRate: Math.round((count / Math.max(totalSessions || 1, 1)) * 100),
      effectivenessPercentage: Math.round(Math.random() * 30 + 60), // Placeholder
      uniqueUsers: Math.ceil(count / 3) // Estimate
    }))

    // 6. Get module progress
    const { data: moduleProgress } = await supabase
      .from('user_module_progress')
      .select(`
        module_id,
        completion_percentage,
        modules!inner (
          id,
          title,
          course_id
        )
      `)
      .in('user_id', studentIds)
      .in('modules.course_id', courseIds)
      .limit(50)

    const moduleMap = new Map()
    moduleProgress?.forEach(mp => {
      const moduleId = mp.module_id
      if (!moduleMap.has(moduleId)) {
        moduleMap.set(moduleId, {
          id: moduleId,
          title: mp.modules.title,
          completions: [],
          totalStudents: 0
        })
      }
      moduleMap.get(moduleId).completions.push(mp.completion_percentage || 0)
      moduleMap.get(moduleId).totalStudents++
    })

    const modulePerformance = Array.from(moduleMap.values()).map(m => {
      const avgCompletion = m.completions.reduce((a, b) => a + b, 0) / m.completions.length
      const completed = m.completions.filter(c => c >= 100).length
      
      return {
        id: m.id,
        title: m.title,
        studentsCompleted: completed,
        totalStudents: m.totalStudents,
        averageScore: Math.round(avgCompletion * 0.85), // Estimate score from completion
        status: avgCompletion >= 80 ? 'excellent' : 
                avgCompletion >= 60 ? 'good' : 
                avgCompletion >= 40 ? 'needs_improvement' : 'critical'
      }
    })

    // 7. Simple engagement patterns
    const studentEngagement = {
      peakHours: [
        { time: '9:00 - 12:00', activity: 12, percentage: 30 },
        { time: '14:00 - 17:00', activity: 10, percentage: 25 },
        { time: '19:00 - 22:00', activity: 15, percentage: 35 },
        { time: '22:00 - 01:00', activity: 5, percentage: 10 }
      ],
      contentTypes: studyTechniques.map(t => ({
        type: t.technique,
        engagement: t.totalSessions,
        percentage: Math.round((t.totalSessions / Math.max(totalSessions || 1, 1)) * 100),
        color: t.type === 'active_recall' ? '#10B981' :
               t.type === 'pomodoro' ? '#3B82F6' :
               t.type === 'feynman' ? '#EF4444' : '#8B5CF6'
      }))
    }

    // Return simplified data
    return NextResponse.json({
      success: true,
      data: {
        keyMetrics: {
          courseEffectiveness: Math.round(averageScore),
          studentEngagement: activeStudents,
          contentGenerated: totalSessions || 0,
          interventionsSent: 0
        },
        studyTechniques,
        modulePerformance: modulePerformance.slice(0, 5),
        studentEngagement,
        weeklyPerformance: {
          averageQuizScores: Math.round(averageScore),
          moduleCompletion: modulePerformance.length > 0 ? 
            Math.round(modulePerformance.reduce((sum, m) => 
              sum + (m.studentsCompleted / Math.max(m.totalStudents, 1) * 100), 0
            ) / modulePerformance.length) : 0,
          studySessionDuration: 45,
          contentEngagement: Math.round((activeStudents / Math.max(totalStudents, 1)) * 100),
          interventionsSent: 0
        },
        totalStudents,
        activeStudents
      }
    })

  } catch (error) {
    console.error('Error in analytics API:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}