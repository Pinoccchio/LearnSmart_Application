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
}

const AuthContext = createContext<AuthContextType | undefined>(undefined)

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null)
  const [isLoading, setIsLoading] = useState(false)
  const router = useRouter()
  const supabase = createClient()

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
        throw new Error('Student accounts cannot access the web platform. Please use the mobile app.')
      default:
        throw new Error('Account role not recognized. Please contact support.')
    }
  }

  useEffect(() => {
    // Simple auth state listener - no auto-authentication
    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange(async (event, session) => {
      console.log('Auth state change:', event, session?.user?.id)
      
      if (event === 'SIGNED_OUT' || !session) {
        setUser(null)
      }
    })

    return () => {
      subscription.unsubscribe()
    }
  }, [])

  const fetchUserProfile = async (userId: string, shouldRedirect = false): Promise<void> => {
    try {
      console.log('🔄 Fetching user profile for:', userId, 'shouldRedirect:', shouldRedirect)
      
      const { data, error } = await supabase
        .from('users')
        .select('*')
        .eq('id', userId)
        .single()

      if (error) {
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
        
        // Redirect after login if requested
        if (shouldRedirect) {
          try {
            handleRoleBasedRedirect(data.role)
          } catch (redirectError: any) {
            await supabase.auth.signOut()
            setUser(null)
            throw redirectError
          }
        }
        
        // Update last_login time
        if (shouldRedirect) {
          supabase
            .from('users')
            .update({ last_login: new Date().toISOString() })
            .eq('id', userId)
            .then(() => {})
            .catch((err: any) => console.warn('Failed to update last_login:', err))
        }
      } else {
        console.warn('⚠️ No user profile found for ID:', userId)
      }
    } catch (error: any) {
      console.error('❌ Error fetching user profile:', error)
      if (shouldRedirect) {
        throw error
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
      router.push('/')
      
    } catch (error) {
      console.error('❌ Logout error:', error)
      setUser(null)
      router.push('/')
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