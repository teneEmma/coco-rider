import { fireEvent, render, screen } from '@testing-library/react';
import { beforeEach, expect, it } from 'vitest';
import App from './App';

beforeEach(() => localStorage.setItem('coco-locale', 'fr'));

it('shows French by default and switches to English', () => {
  render(<App />);
  expect(screen.getByRole('heading', { level: 1 })).toHaveTextContent('Voyagez ensemble');
  expect(screen.getByText(/24 heures avant le départ/)).toBeInTheDocument();

  fireEvent.click(screen.getByRole('button', { name: 'Switch to English' }));

  expect(screen.getByRole('heading', { level: 1 })).toHaveTextContent('Travel together');
  expect(document.documentElement.lang).toBe('en');
});

it('marks store buttons as coming soon until links are configured', () => {
  render(<App />);
  expect(screen.getAllByText('Bientôt disponible').length).toBeGreaterThan(0);
  expect(screen.queryByRole('link', { name: /Google Play/ })).not.toBeInTheDocument();
});
