import { describe, expect, it } from 'vitest';
import { render, screen } from '@testing-library/react';
import { Icon } from './Icon';

describe('Icon', () => {
  it('is decorative (aria-hidden) by default', () => {
    const { container } = render(<Icon name="check" />);
    const svg = container.querySelector('svg');
    expect(svg).not.toBeNull();
    expect(svg).toHaveAttribute('aria-hidden', 'true');
    expect(svg).not.toHaveAttribute('role');
  });

  it('exposes a standalone accessible name when label is provided', () => {
    render(<Icon name="shield-check" label="Безопасно" />);
    expect(screen.getByRole('img', { name: 'Безопасно' })).toBeInTheDocument();
  });
});
