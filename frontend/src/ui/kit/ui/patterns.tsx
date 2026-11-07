import {
  useEffect,
  useId,
  useRef,
  useState,
  type HTMLAttributes,
  type ReactNode,
  type RefObject,
} from 'react';
import { createPortal } from 'react-dom';
import { Icon, type IconName } from '../icons/Icon';
import { cx } from '../lib/cx';
import { Button, IconButton } from './primitives';
import s from './patterns.module.css';
import u from './ui.module.css';

/* ------------------------------------------------------------------ */
/* PageHeader                                                           */
/* ------------------------------------------------------------------ */

export interface PageHeaderProps {
  title: string;
  subtitle?: string;
  onBack?: () => void;
  backLabel?: string;
  action?: ReactNode;
  className?: string;
}

export function PageHeader({
  title,
  subtitle,
  onBack,
  backLabel = 'Назад',
  action,
  className,
}: PageHeaderProps) {
  return (
    <header className={cx(s.pageHeader, className)}>
      {onBack && (
        <button type="button" className={s.pageHeaderBack} aria-label={backLabel} onClick={onBack}>
          <Icon name="arrow-left" />
        </button>
      )}
      <div className={s.pageHeaderText}>
        <h1 className={s.pageHeaderTitle}>{title}</h1>
        {subtitle && <span className={s.pageHeaderSubtitle}>{subtitle}</span>}
      </div>
      {action && <div className={s.pageHeaderAction}>{action}</div>}
    </header>
  );
}

/* ------------------------------------------------------------------ */
/* SectionHeader                                                        */
/* ------------------------------------------------------------------ */

export interface SectionHeaderProps {
  title: string;
  icon?: IconName;
  action?: ReactNode;
  className?: string;
}

export function SectionHeader({ title, icon, action, className }: SectionHeaderProps) {
  return (
    <div className={cx(s.sectionHeader, className)}>
      <h2 className={s.sectionTitle}>
        {icon && <Icon name={icon} className={s.sectionIcon} />}
        {title}
      </h2>
      {action && <div className={s.sectionAction}>{action}</div>}
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* SafetyBand                                                           */
/* ------------------------------------------------------------------ */

export type SafetyVariant = 'ok' | 'warning' | 'blocked';

export interface SafetyBandProps {
  variant?: SafetyVariant;
  title: string;
  children?: ReactNode;
  className?: string;
}

export function SafetyBand({ variant = 'ok', title, children, className }: SafetyBandProps) {
  const blocked = variant === 'blocked';
  return (
    <div
      className={cx(
        s.safetyBand,
        variant === 'warning' && s.safetyBandWarning,
        blocked && s.safetyBandBlocked,
        className,
      )}
      role={blocked ? 'alert' : 'status'}
      aria-live={blocked ? 'assertive' : 'polite'}
    >
      <span className={s.safetyIcon} aria-hidden="true">
        <Icon name={blocked || variant === 'warning' ? 'shield-alert' : 'shield-check'} />
      </span>
      <div className={s.safetyBody}>
        <span className={s.safetyTitle}>{title}</span>
        {children && <span className={s.safetyText}>{children}</span>}
      </div>
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* ActionCard                                                           */
/* ------------------------------------------------------------------ */

export interface ActionCardProps {
  title: string;
  meta?: string;
  icon?: IconName;
  whyLabel?: string;
  why?: ReactNode;
  children?: ReactNode;
  className?: string;
}

export function ActionCard({
  title,
  meta,
  icon,
  whyLabel = 'Зачем',
  why,
  children,
  className,
}: ActionCardProps) {
  return (
    <section className={cx(s.actionCard, className)} aria-label={title}>
      <div className={s.actionCardHead}>
        <h3 className={s.actionCardTitle}>
          {icon && <Icon name={icon} className={s.actionCardIcon} />}
          {title}
        </h3>
        {meta && <span className={s.actionCardMeta}>{meta}</span>}
      </div>
      {why && (
        <div className={s.actionCardWhy}>
          <span className={s.actionCardWhyLabel}>{whyLabel}</span>
          <span className={s.actionCardWhyText}>{why}</span>
        </div>
      )}
      {children && <div className={s.actionCardActions}>{children}</div>}
    </section>
  );
}

/* ------------------------------------------------------------------ */
/* InboxItem / TimelineRow                                              */
/* ------------------------------------------------------------------ */

export interface InboxItemProps {
  title: string;
  meta?: string;
  icon?: ReactNode;
  iconName?: IconName;
  onClick?: () => void;
  className?: string;
}

export function InboxItem({ title, meta, icon, iconName, onClick, className }: InboxItemProps) {
  return (
    <li className={className}>
      <button type="button" className={s.inboxItem} onClick={onClick}>
        <span className={s.inboxIcon} aria-hidden="true">
          {iconName ? <Icon name={iconName} /> : icon}
        </span>
        <span className={s.inboxText}>
          <span className={s.inboxTitle}>{title}</span>
          {meta && <span className={s.inboxMeta}>{meta}</span>}
        </span>
        <Icon name="chevron-right" />
      </button>
    </li>
  );
}

export interface InboxListProps extends HTMLAttributes<HTMLUListElement> {
  children: ReactNode;
}

export function InboxList({ className, children, ...rest }: InboxListProps) {
  return (
    <ul className={cx(s.inboxList, className)} {...rest}>
      {children}
    </ul>
  );
}

export interface TimelineRowProps {
  time: string;
  title: string;
  meta?: string;
  icon?: ReactNode;
  className?: string;
}

export function TimelineRow({ time, title, meta, icon, className }: TimelineRowProps) {
  return (
    <li className={cx(s.timelineRow, className)}>
      <time className={s.timelineTime}>{time}</time>
      {icon && (
        <span className={s.inboxIcon} aria-hidden="true">
          {icon}
        </span>
      )}
      <span className={s.timelineBody}>
        <span className={s.timelineTitle}>{title}</span>
        {meta && <span className={s.timelineMeta}>{meta}</span>}
      </span>
    </li>
  );
}

export interface TimelineProps extends HTMLAttributes<HTMLOListElement> {
  children: ReactNode;
}

export function Timeline({ className, children, ...rest }: TimelineProps) {
  return (
    <ol className={cx(s.timeline, className)} {...rest}>
      {children}
    </ol>
  );
}

/* ------------------------------------------------------------------ */
/* BudgetBar                                                            */
/* ------------------------------------------------------------------ */

export type BudgetStatus = 'ok' | 'warning' | 'danger';

export interface BudgetAxis {
  label: string;
  value: number;
  max: number;
  valueText: string;
  status?: BudgetStatus;
  statusText?: string;
}

export interface BudgetBarProps {
  title?: string;
  period?: string;
  axes: BudgetAxis[];
  footer?: ReactNode;
  className?: string;
}

export function BudgetBar({
  title = 'Бюджет дня',
  period,
  axes,
  footer,
  className,
}: BudgetBarProps) {
  return (
    <section className={cx(s.budget, className)} aria-label={title}>
      <div className={s.budgetHead}>
        <h2 className={s.budgetTitle}>{title}</h2>
        {period && <span className={s.budgetPeriod}>{period}</span>}
      </div>
      <div className={s.budgetAxes}>
        {axes.map((axis) => {
          const max = axis.max > 0 ? axis.max : 1;
          const clamped = Math.min(Math.max(axis.value, 0), max);
          const percent = (clamped / max) * 100;
          const status = axis.status ?? 'ok';
          return (
            <div className={s.budgetAxis} key={axis.label}>
              <div className={s.budgetAxisLabels}>
                <span className={s.budgetAxisName}>{axis.label}</span>
                <span className={s.budgetAxisValue}>{axis.valueText}</span>
              </div>
              <div
                className={u.progressTrack}
                role="progressbar"
                aria-label={axis.label}
                aria-valuenow={clamped}
                aria-valuemin={0}
                aria-valuemax={max}
                aria-valuetext={`${axis.label}: ${axis.valueText}`}
              >
                <div
                  className={cx(
                    u.progressFill,
                    status === 'warning' && u.progressWarning,
                    status === 'danger' && u.progressDanger,
                  )}
                  style={{ width: `${percent}%` }}
                />
              </div>
              {axis.statusText && (
                <span
                  className={cx(
                    s.budgetStatus,
                    status === 'ok' && s.budgetStatusOk,
                    status === 'warning' && s.budgetStatusWarning,
                    status === 'danger' && s.budgetStatusDanger,
                  )}
                >
                  {axis.statusText}
                </span>
              )}
            </div>
          );
        })}
      </div>
      {footer}
    </section>
  );
}

/* ------------------------------------------------------------------ */
/* PortfolioSummary                                                     */
/* ------------------------------------------------------------------ */

export interface PortfolioSummaryProps {
  active: number;
  max: number;
  deferred?: number;
  excluded?: number;
  reasons?: string[];
  note?: string;
  className?: string;
}

export function PortfolioSummary({
  active,
  max,
  deferred,
  excluded,
  reasons,
  note,
  className,
}: PortfolioSummaryProps) {
  return (
    <section className={cx(s.portfolio, className)} aria-label="Портфель">
      <dl className={s.portfolioRow}>
        <dt className={s.portfolioTerm}>Портфель |S|</dt>
        <dd className={s.portfolioValue}>
          {active} / K_max {max}
        </dd>
      </dl>
      {typeof deferred === 'number' && (
        <dl className={s.portfolioRow}>
          <dt className={s.portfolioTerm}>Отложено</dt>
          <dd className={s.portfolioValue}>{deferred}</dd>
        </dl>
      )}
      {typeof excluded === 'number' && (
        <dl className={s.portfolioRow}>
          <dt className={s.portfolioTerm}>Исключено</dt>
          <dd className={s.portfolioValue}>{excluded}</dd>
        </dl>
      )}
      {reasons && reasons.length > 0 && (
        <div className={s.portfolioRow}>
          <span className={s.portfolioTerm}>Причины</span>
          <span className={s.portfolioValue}>{reasons.join(' · ')}</span>
        </div>
      )}
      {note && <p className={s.portfolioNote}>{note}</p>}
    </section>
  );
}

/* ------------------------------------------------------------------ */
/* Expander                                                             */
/* ------------------------------------------------------------------ */

export interface ExpanderProps {
  title: string;
  children: ReactNode;
  defaultOpen?: boolean;
  onToggle?: (open: boolean) => void;
  className?: string;
}

export function Expander({ title, children, defaultOpen = false, onToggle, className }: ExpanderProps) {
  const [open, setOpen] = useState(defaultOpen);
  const panelId = useId();
  return (
    <div className={cx(s.expander, className)}>
      <button
        type="button"
        className={s.expanderButton}
        aria-expanded={open}
        aria-controls={panelId}
        onClick={() => {
          const next = !open;
          setOpen(next);
          onToggle?.(next);
        }}
      >
        <span>{title}</span>
        <span
          className={cx(s.expanderChevron, open && s.expanderChevronOpen)}
          aria-hidden="true"
        >
          <Icon name="chevron-down" />
        </span>
      </button>
      {open && (
        <div className={s.expanderPanel} id={panelId}>
          {children}
        </div>
      )}
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* Empty / Error / Loading                                              */
/* ------------------------------------------------------------------ */

export interface EmptyStateProps {
  title: string;
  children?: ReactNode;
  actions?: ReactNode;
  className?: string;
}

export function EmptyState({ title, children, actions, className }: EmptyStateProps) {
  return (
    <section className={cx(s.state, className)}>
      <span className={s.stateIcon} aria-hidden="true" />
      <h2 className={s.stateTitle}>{title}</h2>
      {children && <p className={s.stateText}>{children}</p>}
      {actions && <div className={s.stateActions}>{actions}</div>}
    </section>
  );
}

export interface ErrorStateProps extends Omit<EmptyStateProps, 'title'> {
  title?: string;
  retryLabel?: string;
  onRetry?: () => void;
}

export function ErrorState({
  title = 'Не удалось загрузить данные',
  children,
  actions,
  retryLabel = 'Повторить',
  onRetry,
  className,
}: ErrorStateProps) {
  return (
    <section className={cx(s.state, s.stateDanger, className)} role="alert">
      <span className={s.stateIcon} aria-hidden="true" />
      <h2 className={s.stateTitle}>{title}</h2>
      {children && <p className={s.stateText}>{children}</p>}
      <div className={s.stateActions}>
        {onRetry && <Button onClick={onRetry}>{retryLabel}</Button>}
        {actions}
      </div>
    </section>
  );
}

export interface LoadingStateProps {
  label?: string;
  rows?: number;
  className?: string;
}

export function LoadingState({ label = 'Загрузка', rows = 4, className }: LoadingStateProps) {
  return (
    <section
      className={cx(s.state, className)}
      role="status"
      aria-busy="true"
      aria-label={label}
    >
      {Array.from({ length: rows }, (_, index) => (
        <span
          key={index}
          className={u.skeleton}
          style={{ width: '100%', height: 'var(--space-4)' }}
          aria-hidden="true"
        />
      ))}
      <span className={u.visuallyHidden}>{label}</span>
    </section>
  );
}

/* ------------------------------------------------------------------ */
/* Dialog / Sheet                                                       */
/* ------------------------------------------------------------------ */

function useDialogBehavior(open: boolean, onClose: () => void, panelRef: RefObject<HTMLDivElement | null>) {
  const previousFocus = useRef<HTMLElement | null>(null);
  const closeRef = useRef(onClose);

  useEffect(() => {
    closeRef.current = onClose;
  }, [onClose]);

  useEffect(() => {
    if (!open) return;
    previousFocus.current = document.activeElement as HTMLElement | null;
    const panel = panelRef.current;
    const focusables = panel?.querySelectorAll<HTMLElement>(
      'button:not([disabled]), [href], input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])',
    );
    focusables?.[0]?.focus();

    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        event.preventDefault();
        closeRef.current();
        return;
      }
      if (event.key !== 'Tab' || !panel) return;
      const nodes = Array.from(
        panel.querySelectorAll<HTMLElement>(
          'button:not([disabled]), [href], input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])',
        ),
      );
      if (nodes.length === 0) {
        event.preventDefault();
        return;
      }
      const first = nodes[0];
      const last = nodes[nodes.length - 1];
      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first.focus();
      }
    };

    document.addEventListener('keydown', onKeyDown);
    return () => {
      document.removeEventListener('keydown', onKeyDown);
      previousFocus.current?.focus?.();
    };
  }, [open, panelRef]);
}

export interface DialogProps {
  open: boolean;
  onClose: () => void;
  title: string;
  children: ReactNode;
  actions?: ReactNode;
  closeLabel?: string;
  className?: string;
}

export function Dialog({
  open,
  onClose,
  title,
  children,
  actions,
  closeLabel = 'Закрыть',
  className,
}: DialogProps) {
  const panelRef = useRef<HTMLDivElement>(null);
  const titleId = useId();
  useDialogBehavior(open, onClose, panelRef);

  if (!open) return null;

  return createPortal(
    <div
      className={s.overlay}
      onMouseDown={(event) => {
        if (event.target === event.currentTarget) onClose();
      }}
    >
      <div
        ref={panelRef}
        className={cx(s.dialog, className)}
        role="dialog"
        aria-modal="true"
        aria-labelledby={titleId}
      >
        <div className={s.dialogHead}>
          <h2 className={s.dialogTitle} id={titleId}>
            {title}
          </h2>
          <IconButton aria-label={closeLabel} onClick={onClose}>
            <Icon name="x" />
          </IconButton>
        </div>
        <div className={s.dialogBody}>{children}</div>
        {actions && <div className={s.dialogActions}>{actions}</div>}
      </div>
    </div>,
    document.body,
  );
}

export interface SheetProps extends DialogProps {
  title: string;
}

export function Sheet({
  open,
  onClose,
  title,
  children,
  actions,
  closeLabel = 'Закрыть',
  className,
}: SheetProps) {
  const panelRef = useRef<HTMLDivElement>(null);
  const titleId = useId();
  useDialogBehavior(open, onClose, panelRef);

  if (!open) return null;

  return createPortal(
    <div
      className={cx(s.overlay, s.overlayBottom)}
      onMouseDown={(event) => {
        if (event.target === event.currentTarget) onClose();
      }}
    >
      <div
        ref={panelRef}
        className={cx(s.sheet, className)}
        role="dialog"
        aria-modal="true"
        aria-labelledby={titleId}
      >
        <div className={s.dialogHead}>
          <h2 className={s.dialogTitle} id={titleId}>
            {title}
          </h2>
          <IconButton aria-label={closeLabel} onClick={onClose}>
            <Icon name="x" />
          </IconButton>
        </div>
        <div className={s.dialogBody}>{children}</div>
        {actions && <div className={s.dialogActions}>{actions}</div>}
      </div>
    </div>,
    document.body,
  );
}

/* ------------------------------------------------------------------ */
/* BottomNav                                                            */
/* ------------------------------------------------------------------ */

export interface BottomNavItem {
  id: string;
  label: string;
  icon?: ReactNode;
  iconName?: IconName;
  href?: string;
  current?: boolean;
}

export interface BottomNavProps {
  items: BottomNavItem[];
  onNavigate?: (id: string) => void;
  assistantLabel?: string;
  onAssistant?: () => void;
  className?: string;
}

export function BottomNav({
  items,
  onNavigate,
  assistantLabel = 'Помощник',
  onAssistant,
  className,
}: BottomNavProps) {
  return (
    <nav className={cx(s.bottomNav, className)} aria-label="Основная навигация">
      {items.map((item) => {
        const content = (
          <>
            <span className={s.bottomNavIcon} aria-hidden="true">
              {item.iconName ? <Icon name={item.iconName} /> : item.icon}
            </span>
            <span>{item.label}</span>
          </>
        );
        return item.href ? (
          <a
            key={item.id}
            className={s.bottomNavItem}
            href={item.href}
            aria-current={item.current ? 'page' : undefined}
          >
            {content}
          </a>
        ) : (
          <button
            key={item.id}
            type="button"
            className={s.bottomNavItem}
            aria-current={item.current ? 'page' : undefined}
            onClick={() => onNavigate?.(item.id)}
          >
            {content}
          </button>
        );
      })}
      <button
        type="button"
        className={cx(s.bottomNavItem, s.bottomNavAssistant)}
        aria-label={assistantLabel}
        onClick={onAssistant}
      >
        <Icon name="send" />
      </button>
    </nav>
  );
}
