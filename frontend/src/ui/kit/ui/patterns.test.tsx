import { useState } from 'react';
import { describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';

import {
  BottomNav,
  ConnectionRow,
  EVOICard,
  Expander,
  NotificationPreview,
  PageHeader,
  PINPad,
  Ring,
  SafetyBand,
  Sheet,
  StatsChart,
  Tile,
  Timeline,
  TimelineRow,
} from '../ui';

describe('PageHeader', () => {
  it('renders a header with h1 and a labelled back button', async () => {
    const user = userEvent.setup();
    const onBack = vi.fn();
    render(<PageHeader title="Сегодня" subtitle="12 ноября" onBack={onBack} />);

    expect(screen.getByRole('banner')).toBeInTheDocument();
    expect(screen.getByRole('heading', { level: 1, name: 'Сегодня' })).toBeInTheDocument();
    const back = screen.getByRole('button', { name: 'Назад' });
    await user.click(back);
    expect(onBack).toHaveBeenCalledTimes(1);
  });
});

describe('SafetyBand', () => {
  it('uses role=status for ok and role=alert for blocked', () => {
    const { rerender } = render(<SafetyBand variant="ok" title="Red flags: нет" />);
    expect(screen.getByRole('status')).toHaveTextContent('Red flags: нет');

    rerender(
      <SafetyBand variant="blocked" title="Сначала безопасность">
        Портфель скрыт
      </SafetyBand>,
    );
    expect(screen.getByRole('alert')).toHaveTextContent('Сначала безопасность');
  });
});

describe('Expander', () => {
  it('toggles aria-expanded and hides the panel', async () => {
    const user = userEvent.setup();
    render(
      <Expander title="Почему это?">
        <p>Объяснение</p>
      </Expander>,
    );

    const trigger = screen.getByRole('button', { name: /Почему это/ });
    expect(trigger).toHaveAttribute('aria-expanded', 'false');
    expect(screen.queryByText('Объяснение')).not.toBeInTheDocument();

    await user.click(trigger);
    expect(trigger).toHaveAttribute('aria-expanded', 'true');
    expect(screen.getByText('Объяснение')).toBeInTheDocument();
  });
});

describe('BottomNav', () => {
  it('renders nav with aria-current and assistant button', () => {
    render(
      <BottomNav
        items={[
          { id: 'food', label: 'Питание' },
          { id: 'vitamins', label: 'Витамины', current: true },
          { id: 'more', label: 'Ещё' },
        ]}
        assistantLabel="Помощник"
      />,
    );

    const nav = screen.getByRole('navigation', { name: 'Основная навигация' });
    expect(nav).toBeInTheDocument();
    expect(screen.getAllByRole('button')).toHaveLength(4);
    expect(screen.getByRole('button', { name: 'Витамины' })).toHaveAttribute('aria-current', 'page');
    expect(screen.getByRole('button', { name: 'Помощник' })).toBeInTheDocument();
  });
});

function SheetHarness() {
  const [open, setOpen] = useState(false);
  return (
    <>
      <button type="button" onClick={() => setOpen(true)}>
        Открыть sheet
      </button>
      <Sheet open={open} onClose={() => setOpen(false)} title="Отложенные">
        <p>Причины</p>
      </Sheet>
    </>
  );
}

describe('Sheet', () => {
  it('is a modal dialog that closes on Escape and returns focus to the trigger', async () => {
    const user = userEvent.setup();
    render(<SheetHarness />);
    const trigger = screen.getByRole('button', { name: 'Открыть sheet' });
    trigger.focus();
    await user.click(trigger);

    const dialog = screen.getByRole('dialog', { name: 'Отложенные' });
    expect(dialog).toHaveAttribute('aria-modal', 'true');

    await user.keyboard('{Escape}');
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
    expect(trigger).toHaveFocus();
  });
});

describe('Timeline', () => {
  it('renders an ordered list with time rows', () => {
    render(
      <Timeline>
        <TimelineRow time="10:00" title="Прогулка" meta="20 мин · 0 ₽" />
        <TimelineRow time="14:00" title="Обед" />
      </Timeline>,
    );
    expect(screen.getAllByRole('listitem')).toHaveLength(2);
    expect(screen.getByText('Прогулка')).toBeInTheDocument();
  });
});

describe('P2 patterns', () => {
  it('Tile is a real button with metric-first content', async () => {
    const user = userEvent.setup();
    const onClick = vi.fn();
    render(<Tile metric="4 / 5" title="Портфель" meta="отложено 2" onClick={onClick} />);
    const tile = screen.getByRole('button', { name: /Портфель/ });
    expect(tile).toHaveAttribute('type', 'button');
    await user.click(tile);
    expect(onClick).toHaveBeenCalled();
  });

  it('Tile exposes wide/soon/placeholder/dense variants', () => {
    render(
      <>
        <Tile wide metric="1 780–1 820" title="Калории" iconName="utensils" />
        <Tile metric="12" title="Шаги" soon />
        <Tile title="Вес" placeholder />
        <Tile metric="1 780–1 820" title="Плотная" dense />
      </>,
    );

    const wide = screen.getByRole('button', { name: /Калории/ });
    expect(wide.className).toMatch(/tileWide/);
    expect(wide.querySelector('svg')).not.toBeNull();

    const soon = screen.getByRole('button', { name: /Шаги/ });
    expect(soon.className).toMatch(/tileSoon/);
    expect(soon).toHaveAttribute('aria-disabled', 'true');
    expect(screen.getByText('скоро')).toBeInTheDocument();

    const placeholder = screen.getByRole('button', { name: /Вес/ });
    expect(placeholder.className).toMatch(/tilePlaceholder/);
    expect(placeholder).toHaveTextContent('—');
    expect(screen.getByText('нет данных')).toBeInTheDocument();

    const dense = screen.getByRole('button', { name: /Плотная/ });
    expect(dense.className).toMatch(/tileDense/);
  });

  it('Ring exposes a progressbar with values', () => {
    render(<Ring label="Приверженность" value={3} max={5} valueText="3 из 5" />);
    const ring = screen.getByRole('progressbar', { name: 'Приверженность' });
    expect(ring).toHaveAttribute('aria-valuenow', '3');
    expect(ring).toHaveAttribute('aria-valuemax', '5');
  });

  it('PINPad accepts keyboard digits and backspace', async () => {
    const user = userEvent.setup();

    function PinHarness() {
      const [pin, setPin] = useState('');
      return <PINPad value={pin} onChange={setPin} />;
    }

    render(<PinHarness />);
    const pad = screen.getByRole('group', { name: 'Введите PIN' });
    pad.focus();
    await user.keyboard('12');
    expect(screen.getByText('2 из 4')).toBeInTheDocument();
    await user.keyboard('{Backspace}');
    expect(screen.getByText('1 из 4')).toBeInTheDocument();
    expect(screen.getByLabelText('Цифра 1')).toBeInTheDocument();
  });

  it('ConnectionRow shows status text; EVOI reveals decision impact', () => {
    render(
      <>
        <ConnectionRow title="HPD" status="warning" statusText="Требует подтверждения" />
        <EVOICard
          rows={[
            { label: 'Влияние', value: 'умеренное' },
            { label: 'Уверенность', value: 'средняя' },
          ]}
        />
      </>,
    );
    expect(screen.getByText('Требует подтверждения')).toBeInTheDocument();
    expect(screen.getByText('Влияние')).toBeInTheDocument();
    expect(screen.getByText('умеренное')).toBeInTheDocument();
  });

  it('NotificationPreview is a labelled article without action affordances', () => {
    render(<NotificationPreview title="Напоминание" body="Пора внести запись" time="09:00" />);
    const article = screen.getByRole('article', { name: 'Предпросмотр уведомления' });
    expect(article).toBeInTheDocument();
    expect(screen.queryByRole('button')).not.toBeInTheDocument();
  });
});

describe('StatsChart', () => {
  it('renders axes, grid, bars and a descriptive aria-label', () => {
    render(
      <StatsChart
        period="week"
        series={[
          { label: 'Пн', value: 10 },
          { label: 'Вт', value: 20 },
        ]}
      />,
    );

    const chart = screen.getByRole('img');
    expect(chart).toHaveAccessibleName(/Статистика за период «Неделя»/);
    expect(chart).toHaveAccessibleName(/Пн: 10/);
    expect(chart).toHaveAccessibleName(/Вт: 20/);
    expect(screen.getAllByTestId('stats-bar')).toHaveLength(2);
    // Axis labels are present (top, middle, baseline).
    expect(screen.getByText('20')).toBeInTheDocument();
    expect(screen.getByText('0')).toBeInTheDocument();
  });

  it('renders the empty state for an empty or all-unknown series', () => {
    const { rerender } = render(<StatsChart period="day" series={[]} />);
    expect(screen.getByRole('status')).toHaveTextContent('Нет данных за период');
    expect(screen.queryByRole('img')).not.toBeInTheDocument();

    rerender(<StatsChart period="day" series={[{ label: 'Пн', value: Number.NaN }]} />);
    expect(screen.getByRole('status')).toHaveTextContent('Нет данных за период');
  });

  it('omits a bar for unknown values without dropping the column', () => {
    render(
      <StatsChart
        period="day"
        series={[
          { label: 'Пн', value: 10 },
          { label: 'Вт', value: Number.NaN },
        ]}
      />,
    );

    expect(screen.getAllByTestId('stats-bar')).toHaveLength(1);
    expect(screen.getAllByTestId('stats-col')).toHaveLength(2);
    expect(screen.getByRole('img')).toHaveAccessibleName(/Вт: нет данных/);
  });

  it('renders an uncertainty band when min/max are known', () => {
    render(
      <StatsChart
        period="month"
        series={[
          { label: 'Май', value: 40, min: 20, max: 60 },
          { label: 'Июнь', value: 50 },
        ]}
      />,
    );

    const ranges = screen.getAllByTestId('stats-range');
    expect(ranges).toHaveLength(1);
    expect(ranges[0].style.height).not.toBe('0%');
    expect(screen.getAllByTestId('stats-bar')).toHaveLength(2);
  });
});
