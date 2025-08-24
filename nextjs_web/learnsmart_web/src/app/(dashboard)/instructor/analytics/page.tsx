"use client"

import { useState } from 'react'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { INSTRUCTOR_COURSE, STUDY_TECHNIQUES, TEACHING_INSIGHTS } from "@/lib/constants"

// TODO: Replace INSTRUCTOR_STATS usage with real API data from /api/instructor/students
// Temporary placeholders until analytics page gets its own real data API
const TEMP_STATS = {
  averageScore: 0,
  activeStudents: 0,
  contentGenerated: 0,
  interventionsSent: 0
}
import { 
  TrendingUp, 
  Users, 
  BookOpen, 
  Clock, 
  Download, 
  Filter, 
  Calendar,
  Brain,
  Target,
  AlertTriangle,
  CheckCircle,
  BarChart3,
  Sparkles,
  Eye,
  MessageSquare
} from "lucide-react"

export default function InstructorAnalytics() {
  const [timeRange, setTimeRange] = useState('month')
  const [showDetailedView, setShowDetailedView] = useState(false)

  return (
    <div>
      <div className="mb-6">
        <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
          <div>
            <h1 className="text-3xl font-bold text-gray-900 dark:text-white">Teaching Analytics</h1>
            <p className="text-gray-600 dark:text-gray-300 mt-1">AI-powered insights for Criminal Jurisprudence course effectiveness</p>
          </div>
          <div className="flex gap-2">
            <Button variant="outline" size="sm">
              <Calendar className="h-4 w-4 mr-2" />
              Time Range
            </Button>
            <Button variant="outline" size="sm">
              <Download className="h-4 w-4 mr-2" />
              Export Report
            </Button>
            <Button size="sm" className="bg-emerald-600 hover:bg-emerald-700 text-white">
              <Brain className="h-4 w-4 mr-2" />
              AI Insights
            </Button>
          </div>
        </div>
      </div>

      {/* Key Teaching Metrics */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium text-gray-900 dark:text-white">Course Effectiveness</CardTitle>
            <Target className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{TEMP_STATS.averageScore}%</div>
            <p className="text-xs text-green-600 mt-1">+2.3% this month</p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium text-gray-900 dark:text-white">Student Engagement</CardTitle>
            <Users className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{TEMP_STATS.activeStudents}</div>
            <p className="text-xs text-emerald-600 mt-1">Active this week</p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium text-gray-900 dark:text-white">Content Generated</CardTitle>
            <Brain className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{TEMP_STATS.contentGenerated}</div>
            <p className="text-xs text-blue-600 mt-1">AI-powered materials</p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium text-gray-900 dark:text-white">Interventions Sent</CardTitle>
            <MessageSquare className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{TEMP_STATS.interventionsSent}</div>
            <p className="text-xs text-amber-600 mt-1">To at-risk students</p>
          </CardContent>
        </Card>
      </div>

      {/* Study Techniques Performance & Teaching Effectiveness */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
        <Card>
          <CardHeader>
            <CardTitle className="text-gray-900 dark:text-white">Study Techniques Performance</CardTitle>
            <CardDescription className="dark:text-gray-300">How different study methods perform in your criminology course</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="space-y-6">
              {STUDY_TECHNIQUES.map((technique, index) => (
                <div key={index} className="space-y-3">
                  <div className="flex justify-between items-start">
                    <div className="flex-1">
                      <h4 className="font-medium text-gray-900 dark:text-white">{technique.name}</h4>
                      <p className="text-sm text-gray-600 dark:text-gray-400">{technique.description}</p>
                    </div>
                    <div className="text-right ml-4">
                      <Badge variant="default" className="bg-emerald-100 dark:bg-emerald-900/20 text-emerald-800 dark:text-emerald-300">
                        {technique.effectiveness}
                      </Badge>
                    </div>
                  </div>
                  
                  <div className="space-y-2">
                    {/* Effectiveness Bar */}
                    <div className="flex justify-between text-sm">
                      <span className="text-gray-600 dark:text-gray-400">Effectiveness in Criminal Law</span>
                      <span className="font-medium text-gray-900 dark:text-white">{technique.effectiveness}</span>
                    </div>
                    <div className="w-full bg-gray-200 dark:bg-gray-600 rounded-full h-2">
                      <div 
                        className="bg-emerald-500 h-2 rounded-full transition-all duration-300"
                        style={{ width: technique.effectiveness }}
                      ></div>
                    </div>
                    
                    {/* Usage Bar */}
                    <div className="flex justify-between text-sm">
                      <span className="text-gray-600 dark:text-gray-400">Student Adoption Rate</span>
                      <span className="font-medium text-gray-900 dark:text-white">{technique.usage}</span>
                    </div>
                    <div className="w-full bg-gray-200 dark:bg-gray-600 rounded-full h-2">
                      <div 
                        className="bg-blue-500 h-2 rounded-full transition-all duration-300"
                        style={{ width: technique.usage }}
                      ></div>
                    </div>
                  </div>

                  <div className="flex gap-2">
                    <Button size="sm" variant="outline">
                      <Eye className="h-4 w-4 mr-2" />
                      View Details
                    </Button>
                    <Button size="sm" variant="outline">
                      <MessageSquare className="h-4 w-4 mr-2" />
                      Recommend to Students
                    </Button>
                  </div>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="text-gray-900 dark:text-white">Module Performance Analysis</CardTitle>
            <CardDescription className="dark:text-gray-300">Student performance breakdown by course modules</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="space-y-6">
              {INSTRUCTOR_COURSE.modules.map((module) => (
                <div key={module.id} className="space-y-3 p-4 border border-gray-200 dark:border-gray-700 rounded-lg bg-white dark:bg-gray-800">
                  <div className="flex justify-between items-start">
                    <div className="flex-1">
                      <h4 className="font-medium text-gray-900 dark:text-white">{module.title}</h4>
                      <div className="flex items-center gap-2 mt-1">
                        <Badge 
                          variant="outline"
                          className={module.status === 'published' ? 'border-green-500 text-green-700 dark:text-green-400' : 'border-amber-500 text-amber-700 dark:text-amber-400'}
                        >
                          {module.status}
                        </Badge>
                        <Badge variant="secondary" className="text-xs dark:text-black dark:bg-gray-300">
                          {module.difficulty}
                        </Badge>
                      </div>
                    </div>
                    <div className="text-right">
                      <div className="text-2xl font-bold text-gray-900 dark:text-white">{module.averageScore}%</div>
                      <p className="text-xs text-gray-600 dark:text-gray-400">Avg Score</p>
                    </div>
                  </div>
                  
                  <div className="grid grid-cols-2 gap-4 text-sm">
                    <div>
                      <span className="text-gray-600 dark:text-gray-400">Completed:</span>
                      <span className="font-medium ml-1 text-gray-900 dark:text-white">{module.studentsCompleted}/{INSTRUCTOR_COURSE.totalStudents}</span>
                    </div>
                    <div>
                      <span className="text-gray-600 dark:text-gray-400">Completion Rate:</span>
                      <span className="font-medium ml-1 text-gray-900 dark:text-white">{Math.round((module.studentsCompleted / INSTRUCTOR_COURSE.totalStudents) * 100)}%</span>
                    </div>
                  </div>
                  
                  <div className="w-full bg-gray-200 dark:bg-gray-600 rounded-full h-3">
                    <div 
                      className={`h-3 rounded-full transition-all duration-300 ${
                        module.averageScore >= 80 ? 'bg-green-500' :
                        module.averageScore >= 70 ? 'bg-emerald-500' :
                        module.averageScore >= 60 ? 'bg-amber-500' : 'bg-red-500'
                      }`}
                      style={{ width: `${(module.studentsCompleted / INSTRUCTOR_COURSE.totalStudents) * 100}%` }}
                    ></div>
                  </div>

                  {module.averageScore < 70 && (
                    <div className="p-3 bg-amber-50 rounded-lg border border-amber-200">
                      <div className="flex items-center">
                        <AlertTriangle className="h-4 w-4 text-amber-600 mr-2" />
                        <p className="text-sm text-amber-700">
                          Below target performance. Consider additional resources or review sessions.
                        </p>
                      </div>
                    </div>
                  )}
                </div>
              ))}
            </div>
          </CardContent>
        </Card>
      </div>

      {/* AI Teaching Insights & Student Engagement Patterns */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2 text-gray-900 dark:text-white">
              <Sparkles className="h-5 w-5 text-blue-500" />
              AI Teaching Insights
            </CardTitle>
            <CardDescription className="dark:text-gray-300">Personalized recommendations to improve teaching effectiveness</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              {TEACHING_INSIGHTS.map((insight, index) => (
                <div 
                  key={index}
                  className={`p-4 rounded-lg border ${
                    insight.type === 'success' ? 'bg-green-50 dark:bg-green-900/20 border-green-200 dark:border-green-800' :
                    insight.type === 'warning' ? 'bg-amber-50 dark:bg-amber-900/20 border-amber-200 dark:border-amber-800' :
                    'bg-blue-50 dark:bg-blue-900/20 border-blue-200 dark:border-blue-800'
                  }`}
                >
                  <div className="flex items-start">
                    <div className={`w-2 h-2 rounded-full mt-2 mr-3 flex-shrink-0 ${
                      insight.type === 'success' ? 'bg-green-500' :
                      insight.type === 'warning' ? 'bg-amber-500' :
                      'bg-blue-500'
                    }`}></div>
                    <div className="flex-1">
                      <h4 className={`font-medium ${
                        insight.type === 'success' ? 'text-green-900 dark:text-green-100' :
                        insight.type === 'warning' ? 'text-amber-900 dark:text-amber-100' :
                        'text-blue-900 dark:text-blue-100'
                      }`}>
                        {insight.title}
                      </h4>
                      <p className={`text-sm mt-1 ${
                        insight.type === 'success' ? 'text-green-700 dark:text-green-300' :
                        insight.type === 'warning' ? 'text-amber-700 dark:text-amber-300' :
                        'text-blue-700 dark:text-blue-300'
                      }`}>
                        {insight.description}
                      </p>
                      <Button 
                        variant="outline" 
                        size="sm" 
                        className={`mt-3 text-xs text-gray-900 dark:text-white ${
                          insight.type === 'success' ? 'border-green-300 dark:border-green-700 hover:bg-green-100 dark:hover:bg-green-800' :
                          insight.type === 'warning' ? 'border-amber-300 dark:border-amber-700 hover:bg-amber-100 dark:hover:bg-amber-800' :
                          'border-blue-300 dark:border-blue-700 hover:bg-blue-100 dark:hover:bg-blue-800'
                        }`}
                      >
                        {insight.action}
                      </Button>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="text-gray-900 dark:text-white">Student Engagement Patterns</CardTitle>
            <CardDescription className="dark:text-gray-300">When and how students interact with your course content</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="space-y-6">
              {/* Peak Activity Times */}
              <div>
                <h4 className="font-medium text-gray-900 dark:text-white mb-3">Peak Study Hours</h4>
                <div className="space-y-3">
                  {[
                    { time: "7:00 - 9:00 PM", activity: 85, label: "Evening Study Peak" },
                    { time: "2:00 - 4:00 PM", activity: 72, label: "Afternoon Sessions" },
                    { time: "10:00 - 12:00 PM", activity: 58, label: "Morning Study" },
                    { time: "8:00 - 10:00 PM", activity: 91, label: "Prime Study Time" }
                  ].map((period, index) => (
                    <div key={index} className="space-y-1">
                      <div className="flex justify-between text-sm">
                        <span className="text-gray-600 dark:text-gray-400">{period.time}</span>
                        <span className="font-medium text-gray-900 dark:text-white">{period.activity}% active</span>
                      </div>
                      <div className="w-full bg-gray-200 dark:bg-gray-600 rounded-full h-2">
                        <div 
                          className="bg-emerald-500 h-2 rounded-full transition-all duration-300"
                          style={{ width: `${period.activity}%` }}
                        ></div>
                      </div>
                      <p className="text-xs text-gray-500 dark:text-gray-400">{period.label}</p>
                    </div>
                  ))}
                </div>
              </div>

              {/* Content Engagement */}
              <div>
                <h4 className="font-medium text-gray-900 dark:text-white mb-3">Content Type Performance</h4>
                <div className="space-y-3">
                  {[
                    { type: "Video Lectures", engagement: 92, color: "bg-blue-500" },
                    { type: "Interactive Quizzes", engagement: 89, color: "bg-emerald-500" },
                    { type: "Case Studies", engagement: 78, color: "bg-purple-500" },
                    { type: "Reading Materials", engagement: 65, color: "bg-amber-500" }
                  ].map((content, index) => (
                    <div key={index} className="flex items-center justify-between p-3 bg-gray-50 dark:bg-gray-800 rounded-lg">
                      <div className="flex items-center">
                        <div className={`w-3 h-3 rounded-full ${content.color} mr-3`}></div>
                        <span className="text-sm font-medium text-gray-900 dark:text-white">{content.type}</span>
                      </div>
                      <div className="text-right">
                        <span className="text-sm font-medium text-gray-900 dark:text-white">{content.engagement}%</span>
                        <p className="text-xs text-gray-500 dark:text-gray-400">engagement</p>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Weekly Performance Summary */}
      <Card>
        <CardHeader>
          <CardTitle className="text-gray-900 dark:text-white">Weekly Teaching Performance Summary</CardTitle>
          <CardDescription className="dark:text-gray-300">Overview of your course impact and student outcomes this week</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            <div className="space-y-4">
              <h4 className="font-medium text-gray-900 dark:text-white">Student Success Metrics</h4>
              <div className="space-y-3">
                <div className="flex justify-between items-center">
                  <span className="text-sm text-gray-600 dark:text-gray-400">Average Quiz Scores</span>
                  <span className="font-medium text-green-600 dark:text-green-400">78.5%</span>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-sm text-gray-600 dark:text-gray-400">Module Completion</span>
                  <span className="font-medium text-emerald-600 dark:text-emerald-400">91%</span>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-sm text-gray-600 dark:text-gray-400">Study Session Duration</span>
                  <span className="font-medium text-blue-600 dark:text-blue-400">42 min avg</span>
                </div>
              </div>
            </div>

            <div className="space-y-4">
              <h4 className="font-medium text-gray-900 dark:text-white">Teaching Effectiveness</h4>
              <div className="space-y-3">
                <div className="flex justify-between items-center">
                  <span className="text-sm text-gray-600 dark:text-gray-400">Content Engagement</span>
                  <span className="font-medium text-emerald-600 dark:text-emerald-400">85%</span>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-sm text-gray-600 dark:text-gray-400">Discussion Participation</span>
                  <span className="font-medium text-blue-600 dark:text-blue-400">67%</span>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-sm text-gray-600 dark:text-gray-400">Assignment Submissions</span>
                  <span className="font-medium text-purple-600 dark:text-purple-400">89%</span>
                </div>
              </div>
            </div>

            <div className="space-y-4">
              <h4 className="font-medium text-gray-900 dark:text-white">AI Recommendations</h4>
              <div className="space-y-2">
                <div className="p-3 bg-blue-50 dark:bg-blue-900/20 rounded-lg border border-blue-200 dark:border-blue-800">
                  <p className="text-xs text-blue-700 dark:text-white">
                    <strong>Peak Engagement:</strong> Schedule important content during 7-9 PM for maximum impact
                  </p>
                </div>
                <div className="p-3 bg-green-50 dark:bg-green-900/20 rounded-lg border border-green-200 dark:border-green-800">
                  <p className="text-xs text-green-700 dark:text-white">
                    <strong>Study Technique:</strong> Promote Active Recall technique - shows 87% effectiveness
                  </p>
                </div>
                <div className="p-3 bg-amber-50 dark:bg-amber-900/20 rounded-lg border border-amber-200 dark:border-amber-800">
                  <p className="text-xs text-amber-700 dark:text-white">
                    <strong>At-Risk Alert:</strong> 2 students need immediate intervention for Criminal Procedure
                  </p>
                </div>
              </div>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  )
}