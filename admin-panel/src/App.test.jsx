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
})
