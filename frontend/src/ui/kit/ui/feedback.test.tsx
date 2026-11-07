import { describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { OfflineIndicator, UpdatePill } from './feedback';

describe('OfflineIndicator', () => {
  it('is a polite status region with a readable label', () => {
    render(<OfflineIndicator />);
    const status = screen.getByRole('status');
    expect(status).toHaveTextContent('Нет соединения');
    expect(status).toHaveAttribute('aria-live', 'polite');
  });
});

describe('UpdatePill', () => {
  it('is a real button that fires its action', async () => {
    const user = userEvent.setup();
    const onClick = vi.fn();
    render(<UpdatePill label="Обновить" onClick={onClick} />);
    const button = screen.getByRole('button', { name: 'Обновить' });
    expect(button).toHaveAttribute('type', 'button');
    await user.click(button);
    expect(onClick).toHaveBeenCalledTimes(1);
  });
});
