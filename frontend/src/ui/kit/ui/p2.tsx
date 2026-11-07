import {
  useId,
  useState,
  type ButtonHTMLAttributes,
  type ReactNode,
} from 'react';
import { Icon, type IconName } from '../icons/Icon';
import { cx } from '../lib/cx';
import { Button, Checkbox, Input } from './primitives';
import { Dialog } from './patterns';
import p2 from './p2.module.css';
import ui from './ui.module.css';

/* ------------------------------------------------------------------ */
/* Tile                                                                 */
/* ------------------------------------------------------------------ */

export interface TileProps extends Omit<ButtonHTMLAttributes<HTMLButtonElement>, 'type'> {
  metric?: string;
  title: string;
  meta?: string;
  dark?: boolean;
  metricSize?: 'lg' | 'sm';
  wide?: boolean;
  soon?: boolean;
  placeholder?: boolean;
  dense?: boolean;
  iconName?: IconName;
}

export function Tile({
  metric,
  title,
  meta,
  dark = false,
  metricSize = 'lg',
  wide = false,
  soon = false,
  placeholder = false,
  dense = false,
  iconName,
  className,
  onClick,
  ...rest
}: TileProps) {
  const value = placeholder ? '—' : metric;
  const micro = placeholder ? 'нет данных' : soon ? 'скоро' : undefined;
  const inert = soon || placeholder;
  return (
    <button
      type="button"
      className={cx(
        p2.tile,
        dark && p2.tileDark,
        wide && p2.tileWide,
        soon && p2.tileSoon,
        placeholder && p2.tilePlaceholder,
        dense && p2.tileDense,
        className,
      )}
      onClick={inert ? undefined : onClick}
      aria-disabled={inert || undefined}
      {...rest}
    >
      {iconName && (
        <span className={p2.tileIcon} aria-hidden="true">
          <Icon name={iconName} />
        </span>
      )}
      {value && (
        <span
          className={cx(p2.tileMetric, metricSize === 'sm' && p2.tileMetricSmall)}
        >
          {value}
        </span>
      )}
      <span className={p2.tileTitle}>{title}</span>
      {meta && <span className={p2.tileMeta}>{meta}</span>}
      {micro && <span className={p2.tileMicro}>{micro}</span>}
      {wide && <Icon name="chevron-right" className={p2.tileChevron} />}
    </button>
  );
}

export interface TileGridProps {
  children: ReactNode;
  className?: string;
}

export function TileGrid({ children, className }: TileGridProps) {
  return <div className={cx(p2.tileGrid, className)}>{children}</div>;
}

/* ------------------------------------------------------------------ */
/* ChartBar                                                             */
/* ------------------------------------------------------------------ */

export interface ChartDatum {
  label: string;
  value: number;
  tone?: 'default' | 'carbs';
}

export interface ChartBarProps {
  title?: string;
  data: ChartDatum[];
  max?: number;
  ariaLabel?: string;
  className?: string;
}

export function ChartBar({ title, data, max, ariaLabel, className }: ChartBarProps) {
  const safeMax = max && max > 0 ? max : Math.max(...data.map((datum) => datum.value), 1);
  const summary = data.map((datum) => `${datum.label}: ${datum.value}`).join(', ');
  return (
    <figure className={cx(p2.chart, className)}>
      {title && <figcaption className={p2.chartTitle}>{title}</figcaption>}
      <div
        className={p2.chartBars}
        role="img"
        aria-label={ariaLabel ?? `Диаграмма. ${summary}`}
      >
        {data.map((datum) => {
          const percent = Math.min(Math.max(datum.value / safeMax, 0), 1) * 100;
          return (
            <span
              key={datum.label}
              className={cx(p2.chartBar, datum.tone === 'carbs' && p2.chartBarCarbs)}
              style={{ height: `${percent}%` }}
              aria-hidden="true"
            />
          );
        })}
      </div>
      <div className={p2.chartLabels} aria-hidden="true">
        {data.map((datum) => (
          <span className={p2.chartLabel} key={datum.label}>
            {datum.label}
          </span>
        ))}
      </div>
    </figure>
  );
}

/* ------------------------------------------------------------------ */
/* StatsChart                                                           */
/* ------------------------------------------------------------------ */

export type StatsPeriod = 'day' | 'week' | 'month';

export interface StatsPoint {
  label: string;
  value: number;
  /** Lower bound of the uncertainty band, when known. */
  min?: number;
  /** Upper bound of the uncertainty band, when known. */
  max?: number;
}

export interface StatsChartProps {
  period: StatsPeriod;
  series: StatsPoint[];
  /** Force the empty state even when series has entries. */
  empty?: boolean;
  title?: string;
  ariaLabel?: string;
  className?: string;
}

const PERIOD_LABEL: Record<StatsPeriod, string> = {
  day: 'День',
  week: 'Неделя',
  month: 'Месяц',
};

const numberFormat = new Intl.NumberFormat('ru-RU', { maximumFractionDigits: 1 });

function isKnown(value: number | undefined): value is number {
  return typeof value === 'number' && Number.isFinite(value);
}

function clampUnit(value: number): number {
  return Math.min(Math.max(value, 0), 1);
}

function rangeBounds(min: number | undefined, max: number | undefined, axisMax: number) {
  if (!isKnown(min) || !isKnown(max)) return undefined;
  return {
    bottom: clampUnit(min / axisMax) * 100,
    height: clampUnit((max - min) / axisMax) * 100,
  };
}

/**
 * StatsChart renders a period series with Y axis labels, grid lines and
 * optional uncertainty bands. Non-finite values are treated as unknown and
 * render no bar; an all-unknown (or explicit empty) series renders the empty
 * state instead of inventing values.
 */
export function StatsChart({
  period,
  series,
  empty = false,
  title,
  ariaLabel,
  className,
}: StatsChartProps) {
  const knownPoints = series.filter(
    (point) => isKnown(point.value) || isKnown(point.min) || isKnown(point.max),
  );
  const upperBounds = series
    .flatMap((point) => [isKnown(point.value) ? point.value : undefined, point.max])
    .filter(isKnown);
  const axisMax = upperBounds.length > 0 ? Math.max(...upperBounds, 1) : 1;
  const showEmpty = empty || series.length === 0 || knownPoints.length === 0;

  const summary = series
    .map((point) => {
      if (!isKnown(point.value)) return `${point.label}: нет данных`;
      const bounds = isKnown(point.min) && isKnown(point.max)
        ? `, диапазон ${numberFormat.format(point.min)}–${numberFormat.format(point.max)}`
        : '';
      return `${point.label}: ${numberFormat.format(point.value)}${bounds}`;
    })
    .join('; ');
  const label =
    ariaLabel ??
    `Статистика за период «${PERIOD_LABEL[period]}». ${summary || 'нет данных'}`;
  const caption = title ?? `Статистика · ${PERIOD_LABEL[period]}`;

  if (showEmpty) {
    return (
      <figure className={cx(p2.statsChart, className)}>
        <figcaption className={p2.statsChartCaption}>{caption}</figcaption>
        <p className={p2.statsEmpty} role="status">
          Нет данных за период
        </p>
      </figure>
    );
  }

  return (
    <figure className={cx(p2.statsChart, className)}>
      <figcaption className={p2.statsChartCaption}>{caption}</figcaption>
      <div className={p2.statsChartBody} role="img" aria-label={label}>
        <div className={p2.statsYAxis} aria-hidden="true">
          <span>{numberFormat.format(axisMax)}</span>
          <span>{numberFormat.format(axisMax / 2)}</span>
          <span>0</span>
        </div>
        <div className={p2.statsPlot}>
          <div className={p2.statsGrid} aria-hidden="true">
            <span className={p2.statsGridLine} />
            <span className={p2.statsGridLine} />
            <span className={p2.statsGridLine} />
          </div>
          <div className={p2.statsBars}>
            {series.map((point) => {
              const bounded = rangeBounds(point.min, point.max, axisMax);
              const barPercent = isKnown(point.value) ? clampUnit(point.value / axisMax) * 100 : 0;
              return (
                <span className={p2.statsCol} key={point.label} data-testid="stats-col">
                  {bounded && (
                    <span
                      className={p2.statsRange}
                      data-testid="stats-range"
                      style={{ bottom: `${bounded.bottom}%`, height: `${bounded.height}%` }}
                      aria-hidden="true"
                    />
                  )}
                  {isKnown(point.value) && (
                    <span
                      className={p2.statsBar}
                      data-testid="stats-bar"
                      style={{ height: `${barPercent}%` }}
                      aria-hidden="true"
                    />
                  )}
                </span>
              );
            })}
          </div>
        </div>
      </div>
      <div className={p2.statsLabels} aria-hidden="true">
        {series.map((point) => (
          <span className={p2.statsLabel} key={point.label}>
            {point.label}
          </span>
        ))}
      </div>
    </figure>
  );
}

/* ------------------------------------------------------------------ */
/* Ring                                                                 */
/* ------------------------------------------------------------------ */

export interface RingProps {
  label: string;
  value: number;
  max?: number;
  valueText?: string;
  className?: string;
}

export function Ring({ label, value, max = 100, valueText, className }: RingProps) {
  const safeMax = max > 0 ? max : 1;
  const clamped = Math.min(Math.max(value, 0), safeMax);
  const radius = 20;
  const circumference = 2 * Math.PI * radius;
  const offset = circumference - (clamped / safeMax) * circumference;
  return (
    <div className={cx(p2.ring, className)}>
      <svg
        className={p2.ringSvg}
        viewBox="0 0 48 48"
        role="progressbar"
        aria-label={label}
        aria-valuenow={clamped}
        aria-valuemin={0}
        aria-valuemax={safeMax}
        aria-valuetext={valueText}
      >
        <circle className={p2.ringTrack} cx="24" cy="24" r={radius} fill="none" strokeWidth="4" />
        <circle
          className={p2.ringValue}
          cx="24"
          cy="24"
          r={radius}
          fill="none"
          strokeWidth="4"
          strokeLinecap="round"
          strokeDasharray={circumference}
          strokeDashoffset={offset}
          transform="rotate(-90 24 24)"
        />
      </svg>
      <span className={p2.ringLabel}>{valueText ?? `${clamped} / ${safeMax}`}</span>
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* PIN pad                                                              */
/* ------------------------------------------------------------------ */

export interface PINPadProps {
  value: string;
  length?: number;
  onChange?: (value: string) => void;
  onComplete?: (value: string) => void;
  label?: string;
  className?: string;
}

export function PINPad({
  value,
  length = 4,
  onChange,
  onComplete,
  label = 'Введите PIN',
  className,
}: PINPadProps) {
  const groupId = useId();

  const update = (next: string) => {
    onChange?.(next);
    if (next.length === length) onComplete?.(next);
  };

  const press = (digit: string) => {
    if (value.length >= length) return;
    update(value + digit);
  };

  const backspace = () => update(value.slice(0, -1));

  return (
    <div
      className={cx(p2.pinPad, className)}
      role="group"
      aria-label={label}
      tabIndex={0}
      onKeyDown={(event) => {
        if (/^[0-9]$/.test(event.key)) {
          event.preventDefault();
          press(event.key);
        } else if (event.key === 'Backspace') {
          event.preventDefault();
          backspace();
        }
      }}
    >
      <div className={p2.pinDots} aria-hidden="true">
        {Array.from({ length }, (_, index) => (
          <span key={index} className={cx(p2.pinDot, index < value.length && p2.pinDotFilled)} />
        ))}
      </div>
      <span className={ui.visuallyHidden} aria-live="polite">
        {value.length} из {length}
      </span>
      <div className={p2.pinGrid}>
        {['1', '2', '3', '4', '5', '6', '7', '8', '9'].map((digit) => (
          <button
            key={digit}
            id={`${groupId}-${digit}`}
            type="button"
            className={p2.pinKey}
            onClick={() => press(digit)}
            aria-label={`Цифра ${digit}`}
          >
            {digit}
          </button>
        ))}
        <span aria-hidden="true" />
        <button id={`${groupId}-0`} type="button" className={p2.pinKey} onClick={() => press('0')} aria-label="Цифра 0">
          0
        </button>
        <button
          type="button"
          className={cx(p2.pinKey, p2.pinKeyAction)}
          onClick={backspace}
          aria-label="Удалить последнюю цифру"
          disabled={value.length === 0}
        >
          ⌫
        </button>
      </div>
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* ChatOverlay                                                          */
/* ------------------------------------------------------------------ */

export interface ChatMessage {
  id: string;
  role: 'user' | 'assistant';
  text: string;
}

export interface ChatOverlayProps {
  open: boolean;
  onClose: () => void;
  title?: string;
  messages: ChatMessage[];
  onSend?: (text: string) => void;
  placeholder?: string;
}

export function ChatOverlay({
  open,
  onClose,
  title = 'Помощник',
  messages,
  onSend,
  placeholder = 'Напишите сообщение',
}: ChatOverlayProps) {
  const [draft, setDraft] = useState('');

  const send = () => {
    const text = draft.trim();
    if (!text) return;
    onSend?.(text);
    setDraft('');
  };

  return (
    <Dialog open={open} onClose={onClose} title={title}>
      <div className={p2.chat}>
        <ul className={p2.chatMessages} role="log" aria-live="polite" aria-relevant="additions" aria-label="Сообщения">
          {messages.map((message) => (
            <li
              key={message.id}
              className={cx(p2.chatMessage, message.role === 'user' && p2.chatMessageUser)}
            >
              <span className={ui.visuallyHidden}>
                {message.role === 'user' ? 'Вы: ' : 'Помощник: '}
              </span>
              {message.text}
            </li>
          ))}
        </ul>
        <form
          className={p2.chatComposer}
          onSubmit={(event) => {
            event.preventDefault();
            send();
          }}
        >
          <Input
            label="Сообщение"
            labelHidden
            className={p2.chatInput}
            value={draft}
            placeholder={placeholder}
            onChange={(event) => setDraft(event.currentTarget.value)}
          />
          <Button type="submit" disabled={draft.trim().length === 0}>
            Отправить
          </Button>
        </form>
      </div>
    </Dialog>
  );
}

/* ------------------------------------------------------------------ */
/* ConsentRow                                                           */
/* ------------------------------------------------------------------ */

export interface ConsentRowProps {
  title: string;
  description?: string;
  checked: boolean;
  onChange?: (checked: boolean) => void;
  disabled?: boolean;
  className?: string;
}

export function ConsentRow({
  title,
  description,
  checked,
  onChange,
  disabled = false,
  className,
}: ConsentRowProps) {
  return (
    <div className={cx(p2.rowCard, className)}>
      <Checkbox
        label={title}
        description={description}
        checked={checked}
        disabled={disabled}
        onChange={(event) => onChange?.(event.currentTarget.checked)}
      />
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* ConnectionRow                                                        */
/* ------------------------------------------------------------------ */

export type ConnectionStatus = 'ok' | 'warning' | 'danger' | 'unknown';

export interface ConnectionRowProps {
  title: string;
  description?: string;
  status: ConnectionStatus;
  statusText?: string;
  action?: ReactNode;
  className?: string;
}

export function ConnectionRow({
  title,
  description,
  status,
  statusText,
  action,
  className,
}: ConnectionRowProps) {
  const dotClass = {
    ok: p2.statusOk,
    warning: p2.statusWarning,
    danger: p2.statusDanger,
    unknown: undefined,
  }[status];
  const statusLabel =
    statusText ??
    { ok: 'Подключено', warning: 'Требует внимания', danger: 'Ошибка', unknown: 'Неизвестно' }[status];

  return (
    <div className={cx(p2.rowCard, className)}>
      <span className={p2.rowCardText}>
        <span className={p2.rowCardTitle}>{title}</span>
        {description && <span className={p2.rowCardDescription}>{description}</span>}
        <span className={p2.statusText}>
          <span className={cx(p2.statusDot, dotClass)} aria-hidden="true" /> {statusLabel}
        </span>
      </span>
      {action && <span className={p2.rowCardAction}>{action}</span>}
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* NotificationPreview                                                  */
/* ------------------------------------------------------------------ */

export interface NotificationPreviewProps {
  app?: string;
  title: string;
  body: string;
  time?: string;
  className?: string;
}

export function NotificationPreview({
  app = 'Кубики здоровья',
  title,
  body,
  time,
  className,
}: NotificationPreviewProps) {
  return (
    <article className={cx(p2.notification, className)} aria-label="Предпросмотр уведомления">
      <div className={p2.notificationHead}>
        <span className={p2.notificationApp}>{app}</span>
        {time && <time className={p2.notificationTime}>{time}</time>}
      </div>
      <span className={p2.notificationTitle}>{title}</span>
      <span className={p2.notificationBody}>{body}</span>
    </article>
  );
}

/* ------------------------------------------------------------------ */
/* CommerceSeparatedFooter                                              */
/* ------------------------------------------------------------------ */

export interface CommerceSeparatedFooterProps {
  note?: string;
  children?: ReactNode;
  className?: string;
}

export function CommerceSeparatedFooter({
  note = 'Покупки — отдельно от медицинского пути. Здесь нет корзины, оплаты, цен и комиссии.',
  children,
  className,
}: CommerceSeparatedFooterProps) {
  return (
    <aside className={cx(p2.commerceFooter, className)} aria-label="Покупки отдельно">
      <p className={p2.commerceNote}>{note}</p>
      {children && <div className={p2.commerceActions}>{children}</div>}
    </aside>
  );
}

/* ------------------------------------------------------------------ */
/* EVOICard                                                             */
/* ------------------------------------------------------------------ */

export interface EVOIRow {
  label: string;
  value: string;
}

export interface EVOICardProps {
  title?: string;
  rows: EVOIRow[];
  note?: string;
  actions?: ReactNode;
  className?: string;
}

export function EVOICard({
  title = 'Почему так',
  rows,
  note,
  actions,
  className,
}: EVOICardProps) {
  return (
    <section className={cx(p2.evoi, className)} aria-label={title}>
      <div className={p2.evoiHead}>
        <h2 className={p2.evoiTitle}>{title}</h2>
      </div>
      <dl className={p2.evoiRows}>
        {rows.map((row) => (
          <div className={p2.evoiRow} key={row.label}>
            <dt className={p2.evoiTerm}>{row.label}</dt>
            <dd className={p2.evoiValue}>{row.value}</dd>
          </div>
        ))}
      </dl>
      {note && <p className={p2.evoiNote}>{note}</p>}
      {actions && <div className={p2.evoiActions}>{actions}</div>}
    </section>
  );
}
