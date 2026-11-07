import type { ReactNode } from 'react';
import { cx } from '../lib/cx';
import s from './shells.module.css';

/**
 * Shells are layout primitives. `header` and `bottomNav` are slots intended for
 * semantic components (`PageHeader` renders <header>, `BottomNav` renders <nav>);
 * the shell itself owns the <main> and <aside> context regions.
 */

export interface AppShellMobileProps {
  header?: ReactNode;
  children: ReactNode;
  context?: ReactNode;
  bottomNav?: ReactNode;
  className?: string;
  /** Render at content height instead of full viewport (gallery/preview use). */
  contained?: boolean;
}

export function AppShellMobile({
  header,
  children,
  context,
  bottomNav,
  className,
  contained = false,
}: AppShellMobileProps) {
  return (
    <div className={cx(s.mobileShell, contained && s.contained, className)}>
      {header}
      <main className={s.main}>{children}</main>
      {context && (
        <aside className={s.context} aria-label="Контекст">
          {context}
        </aside>
      )}
      {bottomNav}
    </div>
  );
}

export type AppShellDesktopProps = AppShellMobileProps;

export function AppShellDesktop({
  header,
  children,
  context,
  bottomNav,
  className,
  contained = false,
}: AppShellDesktopProps) {
  return (
    <div className={cx(s.desktopShell, contained && s.contained, className)}>
      {header}
      <div className={s.desktopColumns}>
        <main className={s.main}>{children}</main>
        {context && (
          <aside className={s.context} aria-label="Контекст">
            {context}
          </aside>
        )}
      </div>
      {bottomNav}
    </div>
  );
}

export interface SubpageShellProps {
  header?: ReactNode;
  children: ReactNode;
  context?: ReactNode;
  actions?: ReactNode;
  bottomNav?: ReactNode;
  className?: string;
  /** Render at content height instead of full viewport (gallery/preview use). */
  contained?: boolean;
}

export function SubpageShell({
  header,
  children,
  context,
  actions,
  bottomNav,
  className,
  contained = false,
}: SubpageShellProps) {
  return (
    <div className={cx(s.subpageShell, contained && s.contained, className)}>
      {header}
      <main className={s.main}>{children}</main>
      {context && (
        <aside className={s.context} aria-label="Контекст">
          {context}
        </aside>
      )}
      {actions && (
        <footer className={s.actions} aria-label="Действия страницы">
          {actions}
        </footer>
      )}
      {bottomNav}
    </div>
  );
}
