import { render, screen, fireEvent } from '@testing-library/react'
import '@testing-library/jest-dom/vitest'
import { describe, it, expect } from 'vitest'
import App from './App'

describe('Smart Farmer auth flow', () => {
  it('shows validation errors for invalid sign-in input', async () => {
    render(<App />)

    fireEvent.change(screen.getByPlaceholderText('you@example.com'), { target: { value: 'invalid-email' } })
    fireEvent.change(screen.getByPlaceholderText('Enter password'), { target: { value: 'short' } })
    fireEvent.click(screen.getAllByRole('button', { name: /^sign in$/i })[1])

    expect(await screen.findByText(/Please enter a valid email address\./i)).toBeInTheDocument()
  })

  it('signs in a seed user and shows the dashboard shell', async () => {
    render(<App />)

    fireEvent.change(screen.getByPlaceholderText('you@example.com'), { target: { value: 'admin@smartfarmer.local' } })
    fireEvent.change(screen.getByPlaceholderText('Enter password'), { target: { value: 'AdminPass1' } })
    fireEvent.click(screen.getAllByRole('button', { name: /^sign in$/i })[1])

    expect(await screen.findByText(/Welcome back, Demo Admin\./i)).toBeInTheDocument()
    expect(screen.getByRole('heading', { name: /Demo Admin · admin/i })).toBeInTheDocument()
  })

  it('shows validation error for missing phone in signup', async () => {
    render(<App />)

    // Switch to signup mode
    fireEvent.click(screen.getByRole('button', { name: /^sign up$/i }))

    // Fill in form without phone
    fireEvent.change(screen.getByPlaceholderText('Your full name'), { target: { value: 'Test User' } })
    fireEvent.change(screen.getAllByPlaceholderText('you@example.com')[0], { target: { value: 'test@example.com' } })
    fireEvent.change(screen.getByPlaceholderText('Create a strong password'), { target: { value: 'TestPass1' } })

    // Click signup button
    fireEvent.click(screen.getByRole('button', { name: /^create account$/i }))

    expect(await screen.findByText(/Phone number is required\./i)).toBeInTheDocument()
  })

  it('shows validation error for duplicate email in signup', async () => {
    render(<App />)

    // Switch to signup mode
    fireEvent.click(screen.getByRole('button', { name: /^sign up$/i }))

    // Try to sign up with demo farmer email
    fireEvent.change(screen.getByPlaceholderText('Your full name'), { target: { value: 'Another Farmer' } })
    fireEvent.change(screen.getAllByPlaceholderText('you@example.com')[0], { target: { value: 'farmer@smartfarmer.local' } })
    fireEvent.change(screen.getByPlaceholderText('Create a strong password'), { target: { value: 'TestPass1' } })
    fireEvent.change(screen.getByPlaceholderText('Your phone number'), { target: { value: '+1111111111' } })

    // Click signup button
    fireEvent.click(screen.getByRole('button', { name: /^create account$/i }))

    expect(await screen.findByText(/An account with that email already exists\./i)).toBeInTheDocument()
  })

  it('successfully signs up a new farmer with phone', async () => {
    render(<App />)

    // Switch to signup mode
    fireEvent.click(screen.getByRole('button', { name: /^sign up$/i }))

    // Fill in complete signup form
    fireEvent.change(screen.getByPlaceholderText('Your full name'), { target: { value: 'New Farmer' } })
    fireEvent.change(screen.getAllByPlaceholderText('you@example.com')[0], { target: { value: 'newfarmer@example.com' } })
    fireEvent.change(screen.getByPlaceholderText('Create a strong password'), { target: { value: 'NewPass1' } })
    fireEvent.change(screen.getByPlaceholderText('Your phone number'), { target: { value: '+9999999999' } })

    // Click signup button
    fireEvent.click(screen.getByRole('button', { name: /^create account$/i }))

    expect(await screen.findByText(/Account created successfully for New Farmer\./i)).toBeInTheDocument()
    // Should see dashboard after successful signup
    expect(screen.getByRole('heading', { name: /New Farmer · farmer/i })).toBeInTheDocument()
  })

  it('signs out user and returns to login screen', async () => {
    render(<App />)

    // Sign in first
    fireEvent.change(screen.getByPlaceholderText('you@example.com'), { target: { value: 'admin@smartfarmer.local' } })
    fireEvent.change(screen.getByPlaceholderText('Enter password'), { target: { value: 'AdminPass1' } })
    fireEvent.click(screen.getAllByRole('button', { name: /^sign in$/i })[1])

    await screen.findByText(/Welcome back, Demo Admin\./i)

    // Find and click sign out button
    const signOutButton = screen.getByRole('button', { name: /^sign out$/i })
    fireEvent.click(signOutButton)

    expect(await screen.findByText(/You have been signed out\./i)).toBeInTheDocument()
    // Should return to login/signup page - check for the email input on login form
    expect(screen.getByPlaceholderText('you@example.com')).toBeInTheDocument()
  })
})
