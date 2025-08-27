"use client"

import { createContext, useContext, useState, useEffect, ReactNode } from 'react'
import { useRouter, usePathname } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import type { User as SupabaseUser } from '@supabase/supabase-js'

interface User {
  id: string
  email: string
  name: string
  role: 'admin' | 'instructor' | 'student'
  status: 'active' | 'inactive' | 'suspended'
  profile_picture: string | null
  last_login: string | null
  created_at: string
  updated_at: string
}

interface AuthContextType {
  user: User | null
  login: (email: string, password: string) => Promise<void>
  register: (email: string, password: string, name: string, role?: 'admin' | 'instructor' | 'student') => Promise<void>
  logout: () => void
  isLoading: boolean
  connectionError: boolean
}

const AuthContext = createContext<AuthContextType | undefined>(undefined)

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null)
  const [isLoading, setIsLoading] = useState(true) // Start with true to check session
  const [connectionError, setConnectionError] = useState(false)
  const router = useRouter()
  const pathname = usePathname()
  const supabase = createClient()


  // Check for existing user with improved error handling and connection monitoring
  const checkAuth = async () => {
    try {
      console.log('🔄 Checking authentication state...')
      setConnectionError(false)
      
      // Add timeout to session check
      const sessionPromise = supabase.auth.getSession()
      const timeoutPromise = new Promise((_, reject) => 
        setTimeout(() => reject(new Error('Session check timeout')), 8000)
      )
      
      const { data: { session }, error: sessionError } = await Promise.race([
        sessionPromise, 
        timeoutPromise
      ]) as any
      
      if (sessionError) {
        if (sessionError.message === 'Session check timeout') {
          console.error('⚠️ Session check timed out - connection issues')
          setConnectionError(true)
          setUser(null)
          return
        }
        console.error('❌ Session error:', sessionError)
        setUser(null)
        return
      }
      
      if (session?.user) {
        console.log('✅ Session found, fetching user profile')
        try {
          await fetchUserProfile(session.user.id, false)
          setConnectionError(false) // Clear connection error if successful
        } catch (profileError) {
          console.error('❌ Profile fetch failed:', profileError)
          // Check if it's a connection issue
          if (profileError.message?.includes('timeout') || profileError.message?.includes('fetch')) {
            setConnectionError(true)
          }
          setUser(null)
        }
      } else {
        console.log('👤 No active session')
        setUser(null)
        setConnectionError(false)
      }
    } catch (error: any) {
      console.error('❌ Auth check error:', error)
      if (error.message?.includes('timeout') || error.message?.includes('fetch')) {
        setConnectionError(true)
      }
      setUser(null)
    } finally {
      setIsLoading(false)
    }
  }

  useEffect(() => {
    // Check authentication on mount
    checkAuth()

    // Listen for auth state changes
    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange(async (event, session) => {
      console.log('Auth state change:', event, session?.user?.id)
      
      if (event === 'SIGNED_IN' && session?.user) {
        console.log('✅ User signed in, fetching profile')
        try {
          await fetchUserProfile(session.user.id, false)
        } catch (error) {
          console.error('❌ Failed to fetch profile on auth change:', error)
          // Don't set user to null here, let them try to login again
        }
      } else if (event === 'SIGNED_OUT' || !session) {
        console.log('👋 User signed out')
        setUser(null)
      } else if (event === 'TOKEN_REFRESHED' && session?.user) {
        console.log('🔄 Token refreshed')
        // Don't refetch profile on token refresh, just continue
      }
    })

    return () => {
      subscription.unsubscribe()
    }
  }, [])

  const fetchUserProfile = async (userId: string, updateLastLogin = false): Promise<void> => {
    try {
      console.log('🔄 Fetching user profile for:', userId)
      
      // Add timeout to profile fetch as well
      const profilePromise = supabase
        .from('users')
        .select('*')
        .eq('id', userId)
        .single()
      
      const timeoutPromise = new Promise((_, reject) => 
        setTimeout(() => reject(new Error('Profile fetch timeout')), 10000)
      )
      
      const { data, error } = await Promise.race([profilePromise, timeoutPromise]) as any

      if (error) {
        if (error.message === 'Profile fetch timeout') {
          console.error('⚠️ Profile fetch timed out for user:', userId)
          throw new Error('Profile fetch timed out. Please try again.')
        }
        console.error('❌ Supabase error fetching profile:', error.message || error)
        throw new Error(`Profile fetch failed: ${error.message || 'Unknown error'}`)
      }

      if (data) {
        const userData = {
          id: data.id,
          email: data.email,
          name: data.name,
          role: data.role,
          status: data.status,
          profile_picture: data.profile_picture,
          last_login: data.last_login,
          created_at: data.created_at,
          updated_at: data.updated_at
        }
        
        console.log('✅ User profile loaded:', userData.email, userData.role)
        setUser(userData)
        
        // Update last_login time if requested (usually on login)
        if (updateLastLogin) {
          // Don't wait for last_login update, do it in background
          supabase
            .from('users')
            .update({ last_login: new Date().toISOString() })
            .eq('id', userId)
            .then(() => console.log('✅ Last login updated'))
            .catch((err: any) => console.warn('⚠️ Failed to update last_login:', err))
        }
      } else {
        console.warn('⚠️ No user profile found for ID:', userId)
        throw new Error('User profile not found')
      }
    } catch (error: any) {
      console.error('❌ Error fetching user profile:', error)
      throw error
    }
  }

  const register = async (email: string, password: string, name: string, role: 'admin' | 'instructor' | 'student' = 'student') => {
    setIsLoading(true)
    
    try {
      // Step 1: Sign up with Supabase Auth with user metadata
      const { data, error } = await supabase.auth.signUp({
        email,
        password,
        options: {
          data: {
            name: name,
            role: role
          },
          emailRedirectTo: `${window.location.origin}/auth/callback`
        }
      })

      if (error) throw error

      // Step 2: If signup succeeds, manually create user profile (since trigger is disabled)
      if (data.user) {
        const timestamp = new Date().toISOString()
        
        const { error: profileError } = await supabase
          .from('users')
          .insert({
            id: data.user.id,
            email: data.user.email!,
            name: name,
            role: role,
            status: 'active',
            profile_picture: null,
            created_at: timestamp,
            updated_at: timestamp
          })
        
        // If profile creation fails, we should handle it more carefully
        if (profileError) {
          console.error('Profile creation failed:', profileError)
          
          // Try to clean up the auth user if profile creation fails
          try {
            // We can't easily delete the auth user here, but we'll log the issue
            console.warn('Auth user created but profile creation failed. User ID:', data.user.id)
          } catch (cleanupError) {
            console.error('Failed to clean up after profile creation error:', cleanupError)
          }
          
          // Now throw the error to be handled by the caller
          throw new Error(`Account created but profile setup failed: ${profileError.message}`)
        }
      } else {
        // This shouldn't happen, but handle it just in case
        throw new Error('User registration returned no user data')
      }
      
    } catch (error) {
      console.error('Registration error:', error)
      throw error
    } finally {
      setIsLoading(false)
    }
  }

  const login = async (email: string, password: string) => {
    setIsLoading(true)
    
    try {
      const { data, error } = await supabase.auth.signInWithPassword({
        email,
        password,
      })

      if (error) throw error

      if (data.user) {
        // Fetch user profile and update last login
        await fetchUserProfile(data.user.id, true)
      }
    } catch (error) {
      console.error('Login error:', error)
      throw error
    } finally {
      setIsLoading(false)
    }
  }


  const logout = async () => {
    setIsLoading(true)
    
    try {
      console.log('🔄 Starting logout process...')
      
      setUser(null)
      
      const { error } = await supabase.auth.signOut({ scope: 'global' })
      if (error) {
        console.error('Supabase signOut error:', error)
      }
      
      try {
        localStorage.removeItem('supabase.auth.token')
        sessionStorage.clear()
        
        const keys = Object.keys(localStorage)
        keys.forEach(key => {
          if (key.includes('supabase') || key.includes('auth')) {
            localStorage.removeItem(key)
          }
        })
      } catch (storageError) {
        console.warn('Error clearing storage:', storageError)
      }
      
      console.log('✅ Logout completed successfully')
      
    } catch (error) {
      console.error('❌ Logout error:', error)
      setUser(null)
    } finally {
      setIsLoading(false)
    }
  }

  return (
    <AuthContext.Provider value={{ user, login, register, logout, isLoading, connectionError }}>
      {children}
      {/* Show connection error banner if there are issues */}
      {connectionError && (
        <div className="fixed top-0 left-0 right-0 z-50 bg-yellow-500 text-white text-center py-2 text-sm">
          ⚠️ Connection issues detected. Some features may not work properly.
        </div>
      )}
    </AuthContext.Provider>
  )
}

export function useAuth() {
  const context = useContext(AuthContext)
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider')
  }
  return context
}