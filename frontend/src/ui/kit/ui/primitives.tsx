import {
  forwardRef,
  useId,
  type ButtonHTMLAttributes,
  type HTMLAttributes,
  type InputHTMLAttributes,
  type KeyboardEvent as ReactKeyboardEvent,
  type ReactNode,
  type SelectHTMLAttributes,
  type TextareaHTMLAttributes,
} from 'react';
import { Icon } from '../icons/Icon';
import { cx } from '../lib/cx';
import s from './ui.module.css';

/* ------------------------------------------------------------------ */
/* Button                                                               */
/* ------------------------------------------------------------------ */

export type ButtonVariant = 'primary' | 'accent' | 'secondary' | 'ghost' | 'danger';

export interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: ButtonVariant;
  loading?: boolean;
  leftIcon?: ReactNode;
  rightIcon?: ReactNode;
  fullWidth?: boolean;
}

export const Button = forwardRef<HTMLButtonElement, ButtonProps>(function Button(
  {
    variant = 'primary',
    loading = false,
    leftIcon,
    rightIcon,
    fullWidth = false,
    disabled,
    className,
    children,
    type = 'button',
    ...rest
  },
  ref,
) {
  const isDisabled = disabled === true || loading;
  return (
    <button
      ref={ref}
      type={type}
      className={cx(s.button, s[variant], fullWidth && s.fullWidth, className)}
      disabled={isDisabled}
      aria-disabled={isDisabled || undefined}
      aria-busy={loading || undefined}
      {...rest}
    >
      {loading ? (
        <span className={s.buttonIcon} aria-hidden="true">
          <span className={s.spinner} />
        </span>
      ) : (
        leftIcon && (
          <span className={s.buttonIcon} aria-hidden="true">
            {leftIcon}
          </span>
        )
      )}
      <span className={s.buttonLabel}>{children}</span>
      {!loading && rightIcon && (
        <span className={s.buttonIcon} aria-hidden="true">
          {rightIcon}
        </span>
      )}
    </button>
  );
});

/* ------------------------------------------------------------------ */
/* IconButton                                                           */
/* ------------------------------------------------------------------ */

export interface IconButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  'aria-label': string;
  loading?: boolean;
}

export const IconButton = forwardRef<HTMLButtonElement, IconButtonProps>(function IconButton(
  { 'aria-label': ariaLabel, loading = false, disabled, className, children, type = 'button', ...rest },
  ref,
) {
  const isDisabled = disabled === true || loading;
  return (
    <button
      ref={ref}
      type={type}
      className={cx(s.iconButton, className)}
      aria-label={ariaLabel}
      disabled={isDisabled}
      aria-disabled={isDisabled || undefined}
      aria-busy={loading || undefined}
      {...rest}
    >
      {loading ? <span className={s.spinner} aria-hidden="true" /> : <span aria-hidden="true">{children}</span>}
    </button>
  );
});

/* ------------------------------------------------------------------ */
/* Input                                                                */
/* ------------------------------------------------------------------ */

export interface InputProps extends Omit<InputHTMLAttributes<HTMLInputElement>, 'id'> {
  id?: string;
  label: string;
  hint?: string;
  error?: string;
  unit?: string;
  labelHidden?: boolean;
}

export const Input = forwardRef<HTMLInputElement, InputProps>(function Input(
  { id, label, hint, error, unit, labelHidden = false, className, required, 'aria-describedby': describedBy, ...rest },
  ref,
) {
  const autoId = useId();
  const inputId = id ?? `input-${autoId}`;
  const hintId = hint ? `${inputId}-hint` : undefined;
  const errorId = error ? `${inputId}-error` : undefined;
  const unitId = unit ? `${inputId}-unit` : undefined;
  const ids = [describedBy, hintId, errorId, unitId].filter(Boolean).join(' ') || undefined;

  return (
    <div className={s.field}>
      <label className={cx(s.label, labelHidden && s.visuallyHidden)} htmlFor={inputId}>
        {label}
        {required && (
          <span className={s.requiredMark} aria-hidden="true">
            {' '}
            *
          </span>
        )}
      </label>
      <div className={s.unitRow}>
        <input
          ref={ref}
          id={inputId}
          className={cx(s.control, error && s.invalid, className)}
          aria-invalid={error ? true : undefined}
          aria-describedby={ids}
          required={required}
          {...rest}
        />
        {unit && (
          <span className={s.unit} id={unitId}>
            {unit}
          </span>
        )}
      </div>
      {hint && (
        <span className={s.hint} id={hintId}>
          {hint}
        </span>
      )}
      {error && (
        <span className={s.error} id={errorId} role="alert">
          {error}
        </span>
      )}
    </div>
  );
});

/* ------------------------------------------------------------------ */
/* Textarea                                                             */
/* ------------------------------------------------------------------ */

export interface TextareaProps extends Omit<TextareaHTMLAttributes<HTMLTextAreaElement>, 'id'> {
  id?: string;
  label: string;
  hint?: string;
  error?: string;
}

export const Textarea = forwardRef<HTMLTextAreaElement, TextareaProps>(function Textarea(
  { id, label, hint, error, className, required, 'aria-describedby': describedBy, ...rest },
  ref,
) {
  const autoId = useId();
  const fieldId = id ?? `textarea-${autoId}`;
  const hintId = hint ? `${fieldId}-hint` : undefined;
  const errorId = error ? `${fieldId}-error` : undefined;
  const ids = [describedBy, hintId, errorId].filter(Boolean).join(' ') || undefined;

  return (
    <div className={s.field}>
      <label className={s.label} htmlFor={fieldId}>
        {label}
      </label>
      <textarea
        ref={ref}
        id={fieldId}
        className={cx(s.control, s.textarea, error && s.invalid, className)}
        aria-invalid={error ? true : undefined}
        aria-describedby={ids}
        required={required}
        {...rest}
      />
      {hint && (
        <span className={s.hint} id={hintId}>
          {hint}
        </span>
      )}
      {error && (
        <span className={s.error} id={errorId} role="alert">
          {error}
        </span>
      )}
    </div>
  );
});

/* ------------------------------------------------------------------ */
/* Select                                                               */
/* ------------------------------------------------------------------ */

export interface SelectOption {
  value: string;
  label: string;
  disabled?: boolean;
}

export interface SelectProps extends Omit<SelectHTMLAttributes<HTMLSelectElement>, 'id' | 'children'> {
  id?: string;
  label: string;
  options: SelectOption[];
  hint?: string;
  error?: string;
  placeholder?: string;
}

export const Select = forwardRef<HTMLSelectElement, SelectProps>(function Select(
  { id, label, options, hint, error, placeholder, className, required, 'aria-describedby': describedBy, ...rest },
  ref,
) {
  const autoId = useId();
  const selectId = id ?? `select-${autoId}`;
  const hintId = hint ? `${selectId}-hint` : undefined;
  const errorId = error ? `${selectId}-error` : undefined;
  const ids = [describedBy, hintId, errorId].filter(Boolean).join(' ') || undefined;

  return (
    <div className={s.field}>
      <label className={s.label} htmlFor={selectId}>
        {label}
      </label>
      <select
        ref={ref}
        id={selectId}
        className={cx(s.control, s.select, error && s.invalid, className)}
        aria-invalid={error ? true : undefined}
        aria-describedby={ids}
        required={required}
        {...rest}
      >
        {placeholder && (
          <option value="" disabled>
            {placeholder}
          </option>
        )}
        {options.map((option) => (
          <option key={option.value} value={option.value} disabled={option.disabled}>
            {option.label}
          </option>
        ))}
      </select>
      {hint && (
        <span className={s.hint} id={hintId}>
          {hint}
        </span>
      )}
      {error && (
        <span className={s.error} id={errorId} role="alert">
          {error}
        </span>
      )}
    </div>
  );
});

/* ------------------------------------------------------------------ */
/* Switch                                                               */
/* ------------------------------------------------------------------ */

export interface SwitchProps {
  id?: string;
  checked: boolean;
  onCheckedChange?: (checked: boolean) => void;
  label: string;
  description?: string;
  disabled?: boolean;
  name?: string;
  className?: string;
}

export function Switch({
  id,
  checked,
  onCheckedChange,
  label,
  description,
  disabled = false,
  name,
  className,
}: SwitchProps) {
  const autoId = useId();
  const switchId = id ?? `switch-${autoId}`;
  const descriptionId = description ? `${switchId}-description` : undefined;

  return (
    <label
      className={cx(s.switchRow, disabled && s.switchRowDisabled, className)}
      htmlFor={switchId}
    >
      <input
        id={switchId}
        name={name}
        type="checkbox"
        role="switch"
        className={s.switchInput}
        checked={checked}
        aria-checked={checked}
        aria-describedby={descriptionId}
        disabled={disabled}
        onChange={(event) => onCheckedChange?.(event.currentTarget.checked)}
      />
      <span className={s.switchControl} aria-hidden="true">
        <span className={s.switchTrack}>
          <span className={s.switchThumb} />
        </span>
      </span>
      <span className={s.switchText}>
        <span className={s.switchLabel}>{label}</span>
        {description && (
          <span className={s.switchDescription} id={descriptionId}>
            {description}
          </span>
        )}
      </span>
    </label>
  );
}

/* ------------------------------------------------------------------ */
/* Checkbox                                                             */
/* ------------------------------------------------------------------ */

export interface CheckboxProps extends Omit<InputHTMLAttributes<HTMLInputElement>, 'type' | 'id'> {
  id?: string;
  label: string;
  description?: string;
}

export const Checkbox = forwardRef<HTMLInputElement, CheckboxProps>(function Checkbox(
  { id, label, description, className, disabled, ...rest },
  ref,
) {
  const autoId = useId();
  const checkboxId = id ?? `checkbox-${autoId}`;
  const labelId = `${checkboxId}-label`;
  const descriptionId = description ? `${checkboxId}-description` : undefined;

  return (
    <label className={cx(s.checkRow, className)} htmlFor={checkboxId}>
      <input
        ref={ref}
        id={checkboxId}
        type="checkbox"
        className={s.checkInput}
        aria-labelledby={labelId}
        aria-describedby={descriptionId}
        disabled={disabled}
        {...rest}
      />
      <span className={s.checkText}>
        <span className={s.checkLabel} id={labelId}>
          {label}
        </span>
        {description && (
          <span className={s.checkDescription} id={descriptionId}>
            {description}
          </span>
        )}
      </span>
    </label>
  );
});

/* ------------------------------------------------------------------ */
/* RadioGroup                                                           */
/* ------------------------------------------------------------------ */

export interface RadioOption {
  value: string;
  label: string;
  disabled?: boolean;
}

export interface RadioGroupProps {
  legend: string;
  name: string;
  value: string;
  options: RadioOption[];
  onChange?: (value: string) => void;
  hint?: string;
  disabled?: boolean;
  className?: string;
}

export function RadioGroup({
  legend,
  name,
  value,
  options,
  onChange,
  hint,
  disabled = false,
  className,
}: RadioGroupProps) {
  const groupId = useId();
  return (
    <fieldset className={cx(s.fieldset, className)} aria-describedby={hint ? `${groupId}-hint` : undefined}>
      <legend className={s.legend}>{legend}</legend>
      {options.map((option) => {
        const optionId = `${groupId}-${option.value}`;
        const isDisabled = disabled || option.disabled;
        return (
          <label className={s.radioRow} key={option.value} htmlFor={optionId}>
            <input
              id={optionId}
              type="radio"
              name={name}
              value={option.value}
              checked={value === option.value}
              disabled={isDisabled}
              className={s.checkInput}
              onChange={() => onChange?.(option.value)}
            />
            <span className={s.checkLabel}>{option.label}</span>
          </label>
        );
      })}
      {hint && (
        <span className={s.hint} id={`${groupId}-hint`}>
          {hint}
        </span>
      )}
    </fieldset>
  );
}

/* ------------------------------------------------------------------ */
/* Segmented (tablist)                                                  */
/* ------------------------------------------------------------------ */

export interface SegmentedOption {
  value: string;
  label: string;
  disabled?: boolean;
}

export interface SegmentedProps {
  ariaLabel: string;
  value: string;
  options: SegmentedOption[];
  onChange?: (value: string) => void;
  className?: string;
}

export function Segmented({ ariaLabel, value, options, onChange, className }: SegmentedProps) {
  const baseId = useId();

  const move = (currentIndex: number, direction: 1 | -1) => {
    const enabled = options
      .map((option, index) => ({ option, index }))
      .filter((entry) => !entry.option.disabled);
    if (enabled.length === 0) return;
    const position = enabled.findIndex((entry) => entry.index === currentIndex);
    const next = enabled[(position + direction + enabled.length) % enabled.length];
    if (next) {
      onChange?.(next.option.value);
      document.getElementById(`${baseId}-tab-${next.option.value}`)?.focus();
    }
  };

  const onKeyDown = (event: ReactKeyboardEvent<HTMLButtonElement>, index: number) => {
    if (event.key === 'ArrowRight') {
      event.preventDefault();
      move(index, 1);
    } else if (event.key === 'ArrowLeft') {
      event.preventDefault();
      move(index, -1);
    } else if (event.key === 'Home') {
      event.preventDefault();
      const first = options.find((option) => !option.disabled);
      if (first) {
        onChange?.(first.value);
        document.getElementById(`${baseId}-tab-${first.value}`)?.focus();
      }
    } else if (event.key === 'End') {
      event.preventDefault();
      const last = [...options].reverse().find((option) => !option.disabled);
      if (last) {
        onChange?.(last.value);
        document.getElementById(`${baseId}-tab-${last.value}`)?.focus();
      }
    }
  };

  return (
    <div className={cx(s.segmented, className)} role="tablist" aria-label={ariaLabel}>
      {options.map((option, index) => {
        const selected = option.value === value;
        return (
          <button
            key={option.value}
            id={`${baseId}-tab-${option.value}`}
            type="button"
            role="tab"
            aria-selected={selected}
            tabIndex={selected ? 0 : -1}
            disabled={option.disabled}
            className={s.segment}
            onClick={() => onChange?.(option.value)}
            onKeyDown={(event) => onKeyDown(event, index)}
          >
            {option.label}
          </button>
        );
      })}
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* Chip / Badge                                                         */
/* ------------------------------------------------------------------ */

export interface ChipProps extends Omit<ButtonHTMLAttributes<HTMLButtonElement>, 'as'> {
  as?: 'span' | 'button';
  selected?: boolean;
  children: ReactNode;
}

export function Chip({ as = 'span', selected = false, className, children, type = 'button', ...rest }: ChipProps) {
  if (as === 'button') {
    return (
      <button
        type={type}
        className={cx(s.chip, s.chipButton, selected && s.chipSelected, className)}
        aria-pressed={selected}
        {...rest}
      >
        {children}
      </button>
    );
  }
  return <span className={cx(s.chip, selected && s.chipSelected, className)}>{children}</span>;
}

export type BadgeTone = 'neutral' | 'accent' | 'warning' | 'danger';

export interface BadgeProps extends HTMLAttributes<HTMLSpanElement> {
  tone?: BadgeTone;
}

export function Badge({ tone = 'neutral', className, children, ...rest }: BadgeProps) {
  const toneClass = {
    neutral: undefined,
    accent: s.badgeAccent,
    warning: s.badgeWarning,
    danger: s.badgeDanger,
  }[tone];
  return (
    <span className={cx(s.badge, toneClass, className)} {...rest}>
      {children}
    </span>
  );
}

/* ------------------------------------------------------------------ */
/* Card / Divider / Skeleton / Spinner                                  */
/* ------------------------------------------------------------------ */

export interface CardProps extends HTMLAttributes<HTMLElement> {
  title?: string;
  children: ReactNode;
}

export function Card({ title, children, className, ...rest }: CardProps) {
  return (
    <section className={cx(s.card, className)} aria-label={title} {...rest}>
      {title && <h2 className={s.cardTitle}>{title}</h2>}
      {children}
    </section>
  );
}

export function Divider({ className, ...rest }: HTMLAttributes<HTMLHRElement>) {
  return <hr className={cx(s.divider, className)} {...rest} />;
}

export interface SkeletonProps extends HTMLAttributes<HTMLDivElement> {
  variant?: 'text' | 'rect' | 'circle';
  width?: string;
  height?: string;
}

export function Skeleton({ variant = 'rect', width, height, className, style, ...rest }: SkeletonProps) {
  return (
    <div
      aria-hidden="true"
      className={cx(s.skeleton, variant === 'text' && s.skeletonText, variant === 'circle' && s.skeletonCircle, className)}
      style={{ width, height, ...style }}
      {...rest}
    />
  );
}

export interface SpinnerProps extends HTMLAttributes<HTMLSpanElement> {
  label?: string;
}

export function Spinner({ label = 'Загрузка', className, ...rest }: SpinnerProps) {
  return (
    <span className={cx(s.spinner, className)} role="status" {...rest}>
      <span className={s.visuallyHidden}>{label}</span>
    </span>
  );
}

/* ------------------------------------------------------------------ */
/* Toast                                                                */
/* ------------------------------------------------------------------ */

export type ToastTone = 'info' | 'success' | 'warning' | 'danger';

export interface ToastProps extends HTMLAttributes<HTMLDivElement> {
  tone?: ToastTone;
  title?: string;
  onClose?: () => void;
  closeLabel?: string;
}

export function Toast({
  tone = 'info',
  title,
  onClose,
  closeLabel = 'Закрыть уведомление',
  className,
  children,
  ...rest
}: ToastProps) {
  const assertive = tone === 'danger' || tone === 'warning';
  return (
    <div
      className={cx(s.toast, tone === 'danger' && s.toastDanger, className)}
      role={assertive ? 'alert' : 'status'}
      aria-live={assertive ? 'assertive' : 'polite'}
      {...rest}
    >
      <span className={s.toastIcon} aria-hidden="true" />
      <div className={s.toastText}>
        {title && <span className={s.toastTitle}>{title}</span>}
        {children && <span className={s.toastBody}>{children}</span>}
      </div>
      {onClose && (
        <IconButton aria-label={closeLabel} onClick={onClose}>
          <Icon name="x" />
        </IconButton>
      )}
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* Avatar                                                               */
/* ------------------------------------------------------------------ */

export interface AvatarProps {
  label: string;
  initials?: string;
  src?: string;
  className?: string;
}

export function Avatar({ label, initials, src, className }: AvatarProps) {
  return (
    <span className={cx(s.avatar, className)} role="img" aria-label={label}>
      {src ? <img className={s.avatarImage} src={src} alt="" aria-hidden="true" /> : <span aria-hidden="true">{initials}</span>}
    </span>
  );
}

/* ------------------------------------------------------------------ */
/* Search                                                               */
/* ------------------------------------------------------------------ */

export interface SearchProps extends Omit<InputHTMLAttributes<HTMLInputElement>, 'type' | 'value' | 'onChange'> {
  label?: string;
  value: string;
  onChange?: (value: string) => void;
  onClear?: () => void;
  clearLabel?: string;
}

export const Search = forwardRef<HTMLInputElement, SearchProps>(function Search(
  { label = 'Поиск', value, onChange, onClear, clearLabel = 'Очистить поиск', className, id, ...rest },
  ref,
) {
  const autoId = useId();
  const searchId = id ?? `search-${autoId}`;
  return (
    <div className={s.field}>
      <label className={s.visuallyHidden} htmlFor={searchId}>
        {label}
      </label>
      <div className={s.searchWrap}>
        <span className={s.searchIcon} aria-hidden="true">
          <svg viewBox="0 0 24 24" width="100%" height="100%" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden="true">
            <circle cx="11" cy="11" r="7" />
            <path d="m20 20-3.5-3.5" />
          </svg>
        </span>
        <input
          ref={ref}
          id={searchId}
          type="search"
          className={cx(s.control, s.searchInput, className)}
          value={value}
          onChange={(event) => onChange?.(event.currentTarget.value)}
          {...rest}
        />
        {value && onClear && (
          <button type="button" className={s.searchClear} aria-label={clearLabel} onClick={onClear}>
            <Icon name="x" />
          </button>
        )}
      </div>
    </div>
  );
});

/* ------------------------------------------------------------------ */
/* Progress                                                             */
/* ------------------------------------------------------------------ */

export type ProgressTone = 'accent' | 'warning' | 'danger';

export interface ProgressProps {
  label: string;
  value: number;
  min?: number;
  max?: number;
  valueText?: string;
  tone?: ProgressTone;
  className?: string;
  hideValueLabel?: boolean;
}

export function Progress({
  label,
  value,
  min = 0,
  max = 100,
  valueText,
  tone = 'accent',
  className,
  hideValueLabel = false,
}: ProgressProps) {
  const safeMax = max > min ? max : min + 1;
  const clamped = Math.min(Math.max(value, min), safeMax);
  const percent = ((clamped - min) / (safeMax - min)) * 100;
  const toneClass = tone === 'warning' ? s.progressWarning : tone === 'danger' ? s.progressDanger : undefined;

  return (
    <div className={cx(s.progressWrap, className)}>
      <div className={s.progressHead}>
        <span>{label}</span>
        {!hideValueLabel && <span>{valueText ?? `${clamped} / ${safeMax}`}</span>}
      </div>
      <div
        className={s.progressTrack}
        role="progressbar"
        aria-label={label}
        aria-valuenow={clamped}
        aria-valuemin={min}
        aria-valuemax={safeMax}
        aria-valuetext={valueText}
      >
        <div className={cx(s.progressFill, toneClass)} style={{ width: `${percent}%` }} />
      </div>
    </div>
  );
}
