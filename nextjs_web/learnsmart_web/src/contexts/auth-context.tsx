"use client"

import { createContext, useContext, useState, useEffect, ReactNode } from 'react'
import { useRouter } from 'next/navigation'
import { supabase } from '@/lib/supabase'
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
}

const AuthContext = createContext<AuthContextType | undefined>(undefined)

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null)
  const [isLoading, setIsLoading] = useState(true)
  const router = useRouter()

  // Helper function for role-based redirects
  const handleRoleBasedRedirect = (userRole: string) => {
    switch (userRole) {
      case 'admin':
        router.push('/admin')
        break
      case 'instructor':
        router.push('/instructor')
        break
      case 'student':
        // Block student access to web platform
        throw new Error('Student accounts cannot access the web platform. Please use the mobile app.')
      default:
        throw new Error('Account role not recognized. Please contact support.')
    }
  }

  useEffect(() => {
    // Get initial session
    supabase.auth.getSession().then(({ data: { session } }) => {
      if (session) {
        fetchUserProfile(session.user.id)
      }
      setIsLoading(false)
    })

    // Listen for auth changes
    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange(async (event, session) => {
      if (session) {
        await fetchUserProfile(session.user.id)
      } else {
        setUser(null)
      }
      setIsLoading(false)
    })

    return () => subscription.unsubscribe()
  }, [])

  const fetchUserProfile = async (userId: string, shouldRedirect = false, retryCount = 0) => {
    try {
      const { data, error } = await supabase
        .from('users')
        .select('*')
        .eq('id', userId)
        .single()

      if (error) {
        console.error('Supabase error fetching profile:', error)
        
        // Retry logic for network errors (max 3 retries)
        if (retryCount < 3 && (error.code === 'NETWORK_ERROR' || error.code === 'CONNECTION_ERROR')) {
          console.log(`Retrying fetchUserProfile (${retryCount + 1}/3)...`)
          // Wait for a short time before retrying
          await new Promise(resolve => setTimeout(resolve, 1000))
          return fetchUserProfile(userId, shouldRedirect, retryCount + 1)
        }
        
        throw error
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
        
        setUser(userData)
        
        // Only redirect on fresh login, not on page reload
        if (shouldRedirect) {
          try {
            handleRoleBasedRedirect(data.role)
          } catch (redirectError: any) {
            // If redirect fails (e.g., student access blocked), logout and throw error
            await supabase.auth.signOut()
            setUser(null)
            throw redirectError
          }
        }
        
        // Update last_login time
        if (shouldRedirect) {
          // Don't await this, just fire and forget
          supabase
            .from('users')
            .update({ last_login: new Date().toISOString() })
            .eq('id', userId)
            .then()
            .catch(err => console.warn('Failed to update last_login:', err))
        }
      } else {
        console.warn('No user profile found for ID:', userId)
      }
    } catch (error: any) {
      console.error('Error fetching user profile:', error)
      
      // If this was a login attempt (shouldRedirect), report the error
      if (shouldRedirect) {
        // Set error state that can be accessed by UI components
        console.error(`Profile fetch failed: ${error.message || 'Unknown error'}`)
      }
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
        // Fetch user profile and trigger redirect
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
      const { error } = await supabase.auth.signOut()
      if (error) throw error
      setUser(null)
    } catch (error) {
      console.error('Logout error:', error)
    } finally {
      setIsLoading(false)
    }
  }

  return (
    <AuthContext.Provider value={{ user, login, register, logout, isLoading }}>
      {children}
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