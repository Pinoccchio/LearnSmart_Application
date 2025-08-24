"use client"

import { useAuth } from '@/contexts/auth-context'
import { useRouter } from 'next/navigation'
import { useEffect, useState } from 'react'
import Image from 'next/image'
import LandingPage from '@/components/landing/landing-page'

export default function Home() {
  const { user, isLoading } = useAuth()
  const router = useRouter()
  const [redirecting, setRedirecting] = useState(false)

  useEffect(() => {
    if (!isLoading && user) {
      // Set redirecting state to show loading while redirect happens
      setRedirecting(true)
      
      // Redirect authenticated users based on their role
      if (user.role === 'admin') {
        router.push('/admin')
      } else if (user.role === 'instructor') {
        router.push('/instructor')
      } else {
        router.push('/admin') // Default fallback
      }
    }
  }, [user, isLoading, router])

  if (isLoading || redirecting) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-blue-50 via-white to-blue-100 dark:from-gray-900 dark:via-gray-800 dark:to-gray-900 flex flex-col items-center justify-center">
        <div className="mb-8">
          <Image
            src="/images/logo/logo.png"
            alt="LearnSmart Logo"
            width={250}
            height={100}
            className="h-20 w-auto rounded-lg"
            priority
          />
        </div>
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary"></div>
        <p className="mt-4 text-lg text-gray-600 dark:text-gray-300">
          {redirecting ? 'Redirecting to dashboard...' : 'Loading...'}
        </p>
      </div>
    )
  }

  // Show landing page for unauthenticated users
  return <LandingPage />
}