import type { ButtonHTMLAttributes } from 'react';
import { Icon } from '../icons/Icon';
import { cx } from '../lib/cx';
import s from './feedback.module.css';

/* ------------------------------------------------------------------ */
/* OfflineIndicator                                                     */
/* ------------------------------------------------------------------ */

export interface OfflineIndicatorProps {
  label?: string;
  className?: string;
}

/** Non-blocking connectivity status for shells and forms. */
export function OfflineIndicator({ label = 'Нет соединения', className }: OfflineIndicatorProps) {
  return (
    <div className={cx(s.offline, className)} role="status" aria-live="polite">
      <Icon name="circle-alert" />
      <span>{label}</span>
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* UpdatePill                                                           */
/* ------------------------------------------------------------------ */

export interface UpdatePillProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  label?: string;
}

/** Small action surfaced when a new app shell version is available. */
export function UpdatePill({
  label = 'Доступно обновление',
  className,
  type = 'button',
  ...rest
}: UpdatePillProps) {
  return (
    <button type={type} className={cx(s.updatePill, className)} {...rest}>
      <Icon name="plus" />
      <span>{label}</span>
    </button>
  );
}
