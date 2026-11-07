import { useState } from 'react';
import { describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';

import {
  ActionCard,
  Button,
  Checkbox,
  Dialog,
  Input,
  Progress,
  RadioGroup,
  Segmented,
  Switch,
  Textarea,
  Toast,
} from '../ui';
import { BudgetBar } from '../ui/patterns';

describe('Button', () => {
  it('renders a real button with type=button and fires onClick', async () => {
    const user = userEvent.setup();
    const onClick = vi.fn();
    render(<Button onClick={onClick}>Сохранить</Button>);

    const button = screen.getByRole('button', { name: 'Сохранить' });
    expect(button).toHaveAttribute('type', 'button');
    expect(button).toBeEnabled();

    await user.click(button);
    expect(onClick).toHaveBeenCalledTimes(1);
  });

  it('is disabled when disabled or loading', () => {
    const { rerender } = render(<Button disabled>Недоступно</Button>);
    expect(screen.getByRole('button', { name: 'Недоступно' })).toBeDisabled();

    rerender(<Button loading>Отправка</Button>);
    const button = screen.getByRole('button', { name: 'Отправка' });
    expect(button).toBeDisabled();
    expect(button).toHaveAttribute('aria-busy', 'true');
  });

  it('renders primary and accent variants with distinct classes', () => {
    const { rerender } = render(<Button>Основная</Button>);
    expect(screen.getByRole('button', { name: 'Основная' }).className).toMatch(/primary/);

    rerender(<Button variant="accent">Акцент</Button>);
    const accent = screen.getByRole('button', { name: 'Акцент' });
    expect(accent.className).toMatch(/accent/);
    expect(accent.className).not.toMatch(/primary/);
  });
});

describe('Input', () => {
  it('associates label, hint, error, unit and aria-invalid', () => {
    render(
      <Input
        label="Вес"
        hint="В килограммах"
        error="Укажите значение"
        unit="кг"
        defaultValue="84,2"
      />,
    );

    const input = screen.getByLabelText('Вес');
    expect(input).toBeInTheDocument();
    expect(input).toHaveValue('84,2');
    expect(input).toHaveAttribute('aria-invalid', 'true');

    const describedBy = input.getAttribute('aria-describedby');
    expect(describedBy).toBeTruthy();
    const ids = describedBy!.split(' ');
    expect(document.getElementById(ids[0])).toHaveTextContent('В килограммах');
    expect(document.getElementById(ids[1])).toHaveTextContent('Укажите значение');
    expect(document.getElementById(ids[2])).toHaveTextContent('кг');
  });

  it('does not set aria-invalid without an error', () => {
    render(<Input label="Пульс" />);
    expect(screen.getByLabelText('Пульс')).not.toHaveAttribute('aria-invalid');
  });
});

describe('Textarea', () => {
  it('renders a labelled textarea', async () => {
    const user = userEvent.setup();
    render(<Textarea label="Заметка" hint="Без PHI" />);
    const field = screen.getByLabelText('Заметка');
    expect(field.tagName).toBe('TEXTAREA');
    await user.type(field, 'Текст');
    expect(field).toHaveValue('Текст');
  });
});

describe('Switch', () => {
  it('exposes role=switch, aria-checked and toggles by click', async () => {
    const user = userEvent.setup();
    const onCheckedChange = vi.fn();
    render(
      <Switch
        label="Напоминания"
        description="Только в приложении"
        checked={false}
        onCheckedChange={onCheckedChange}
      />,
    );

    const control = screen.getByRole('switch', { name: /Напоминания/ });
    expect(control).toHaveAttribute('aria-checked', 'false');
    expect(control).not.toBeChecked();

    await user.click(control);
    expect(onCheckedChange).toHaveBeenCalledWith(true);
  });

  it('toggles with the keyboard (Space)', async () => {
    const user = userEvent.setup();
    const onCheckedChange = vi.fn();
    render(<Switch label="Синхронизация" checked={false} onCheckedChange={onCheckedChange} />);

    const control = screen.getByRole('switch', { name: /Синхронизация/ });
    control.focus();
    await user.keyboard(' ');
    expect(onCheckedChange).toHaveBeenCalledWith(true);
  });

  it('is disabled and does not fire when disabled', async () => {
    const user = userEvent.setup();
    const onCheckedChange = vi.fn();
    render(<Switch label="Отключено" checked={false} disabled onCheckedChange={onCheckedChange} />);
    const control = screen.getByRole('switch', { name: /Отключено/ });
    expect(control).toBeDisabled();
    await user.click(control);
    expect(onCheckedChange).not.toHaveBeenCalled();
  });
});

describe('Checkbox', () => {
  it('renders a native checkbox with label and description', async () => {
    const user = userEvent.setup();
    const onChange = vi.fn();
    render(
      <Checkbox label="Согласие" description="Можно отозвать" onChange={onChange} />,
    );
    const checkbox = screen.getByRole('checkbox', { name: 'Согласие' });
    expect(checkbox).toHaveAttribute('type', 'checkbox');
    const describedBy = checkbox.getAttribute('aria-describedby');
    expect(document.getElementById(describedBy!)).toHaveTextContent('Можно отозвать');

    await user.click(checkbox);
    expect(onChange).toHaveBeenCalledTimes(1);
  });
});

describe('RadioGroup', () => {
  it('renders a fieldset/legend and selected radio', async () => {
    const user = userEvent.setup();
    const onChange = vi.fn();
    render(
      <RadioGroup
        legend="Пол"
        name="sex"
        value="female"
        onChange={onChange}
        options={[
          { value: 'female', label: 'Женский' },
          { value: 'male', label: 'Мужской' },
        ]}
      />,
    );

    const group = screen.getByRole('group', { name: 'Пол' });
    expect(group.tagName).toBe('FIELDSET');

    expect(screen.getByRole('radio', { name: 'Женский' })).toBeChecked();
    expect(screen.getByRole('radio', { name: 'Мужской' })).not.toBeChecked();

    await user.click(screen.getByRole('radio', { name: 'Мужской' }));
    expect(onChange).toHaveBeenCalledWith('male');
  });
});

describe('Segmented', () => {
  it('exposes tablist/tab roles, aria-selected and keyboard navigation', async () => {
    const user = userEvent.setup();
    const onChange = vi.fn();
    render(
      <Segmented
        ariaLabel="Период"
        value="day"
        onChange={onChange}
        options={[
          { value: 'day', label: 'День' },
          { value: 'week', label: 'Неделя' },
          { value: 'month', label: 'Месяц' },
        ]}
      />,
    );

    const tablist = screen.getByRole('tablist', { name: 'Период' });
    expect(tablist).toBeInTheDocument();
    const tabs = screen.getAllByRole('tab');
    expect(tabs).toHaveLength(3);
    expect(tabs[0]).toHaveAttribute('aria-selected', 'true');
    expect(tabs[1]).toHaveAttribute('aria-selected', 'false');

    await user.click(tabs[2]);
    expect(onChange).toHaveBeenCalledWith('month');

    tabs[0].focus();
    await user.keyboard('{ArrowRight}');
    expect(onChange).toHaveBeenCalledWith('week');
  });

  it('keeps only the selected tab in the tab order', () => {
    render(
      <Segmented
        ariaLabel="Период"
        value="week"
        options={[
          { value: 'day', label: 'День' },
          { value: 'week', label: 'Неделя' },
        ]}
      />,
    );
    expect(screen.getByRole('tab', { name: 'День' })).toHaveAttribute('tabindex', '-1');
    expect(screen.getByRole('tab', { name: 'Неделя' })).toHaveAttribute('tabindex', '0');
  });
});

function DialogHarness() {
  const [open, setOpen] = useState(false);
  return (
    <>
      <button type="button" onClick={() => setOpen(true)}>
        Открыть
      </button>
      <Dialog open={open} onClose={() => setOpen(false)} title="Почему это?">
        <p>Объяснение действия</p>
        <button type="button" onClick={() => setOpen(false)}>
          Понятно
        </button>
      </Dialog>
    </>
  );
}

describe('Dialog', () => {
  it('has role=dialog, aria-modal and closes on Escape returning focus', async () => {
    const user = userEvent.setup();
    render(<DialogHarness />);

    const trigger = screen.getByRole('button', { name: 'Открыть' });
    trigger.focus();
    await user.click(trigger);

    const dialog = screen.getByRole('dialog', { name: 'Почему это?' });
    expect(dialog).toHaveAttribute('aria-modal', 'true');
    expect(screen.getByRole('button', { name: 'Закрыть' })).toHaveFocus();

    await user.keyboard('{Escape}');
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
    expect(trigger).toHaveFocus();
  });

  it('closes from the close button', async () => {
    const user = userEvent.setup();
    render(<DialogHarness />);
    await user.click(screen.getByRole('button', { name: 'Открыть' }));
    expect(screen.getByRole('dialog')).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Закрыть' }));
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
  });
});

describe('Progress', () => {
  it('renders role=progressbar with valuenow/min/max and readable text', () => {
    render(
      <Progress label="Время" value={7} min={0} max={10} valueText="2–3 часа из 3" />,
    );
    const bar = screen.getByRole('progressbar', { name: 'Время' });
    expect(bar).toHaveAttribute('aria-valuenow', '7');
    expect(bar).toHaveAttribute('aria-valuemin', '0');
    expect(bar).toHaveAttribute('aria-valuemax', '10');
    expect(bar).toHaveAttribute('aria-valuetext', '2–3 часа из 3');
    expect(screen.getByText('2–3 часа из 3')).toBeInTheDocument();
  });
});

describe('Toast', () => {
  it('uses role=status for info and role=alert for danger', () => {
    const { rerender } = render(<Toast title="Сохранено" tone="info" />);
    expect(screen.getByRole('status')).toHaveTextContent('Сохранено');

    rerender(<Toast title="Ошибка" tone="danger" />);
    expect(screen.getByRole('alert')).toHaveTextContent('Ошибка');
  });
});

describe('BudgetBar', () => {
  it('renders three progressbars with readable values', () => {
    render(
      <BudgetBar
        axes={[
          { label: 'Время', value: 20, max: 30, valueText: '2–3 ч / 3 ч', statusText: 'влезает' },
          { label: 'Внимание', value: 5, max: 10, valueText: 'средне', status: 'warning' },
          { label: 'Деньги', value: 400, max: 600, valueText: '≈300–500 / 600' },
        ]}
      />,
    );

    const bars = screen.getAllByRole('progressbar');
    expect(bars).toHaveLength(3);
    expect(bars[0]).toHaveAttribute('aria-valuetext', 'Время: 2–3 ч / 3 ч');
    expect(bars[0]).toHaveAttribute('aria-valuenow', '20');
    expect(bars[1]).toHaveAttribute('aria-valuenow', '5');
    expect(bars[2]).toHaveAttribute('aria-valuemax', '600');
  });
});

describe('ActionCard', () => {
  it('renders title, why and action buttons', () => {
    render(
      <ActionCard title="Прогулка 20 мин" meta="20 мин · 0 ₽" why="Движение → энергия">
        <Button variant="primary">Сделано</Button>
        <Button variant="secondary">Перенести</Button>
      </ActionCard>,
    );

    expect(screen.getByRole('heading', { name: 'Прогулка 20 мин' })).toBeInTheDocument();
    expect(screen.getByText('Движение → энергия')).toBeInTheDocument();
    const actions = screen.getAllByRole('button');
    expect(actions).toHaveLength(2);
    actions.forEach((action) => {
      expect(action.className).toBeTruthy();
      expect(action).toHaveAttribute('type', 'button');
    });
  });
});
