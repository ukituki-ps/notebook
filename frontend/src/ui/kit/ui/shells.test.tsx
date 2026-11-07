import { describe, expect, it } from 'vitest';
import { render, screen } from '@testing-library/react';
import { BottomNav, PageHeader } from '../ui';
import { AppShellDesktop, AppShellMobile, SubpageShell } from './shells';

const nav = (
  <BottomNav
    items={[
      { id: 'today', label: 'Сегодня', iconName: 'heart-pulse', current: true },
      { id: 'more', label: 'Ещё', iconName: 'settings' },
    ]}
  />
);

describe('AppShellMobile', () => {
  it('provides semantic header, main, context and navigation regions', () => {
    render(
      <AppShellMobile
        header={<PageHeader title="Сегодня" />}
        context={<p>Контекст</p>}
        bottomNav={nav}
      >
        <p>Основной контент</p>
      </AppShellMobile>,
    );

    expect(screen.getByRole('banner')).toBeInTheDocument();
    expect(screen.getByRole('main')).toHaveTextContent('Основной контент');
    expect(screen.getByRole('complementary', { name: 'Контекст' })).toHaveTextContent('Контекст');
    expect(screen.getByRole('navigation', { name: 'Основная навигация' })).toBeInTheDocument();
  });
});

describe('AppShellDesktop', () => {
  it('keeps the main and context slots distinct', () => {
    render(
      <AppShellDesktop header={<PageHeader title="Desktop" />} context={<p>Правая колонка</p>}>
        <p>Левая колонка</p>
      </AppShellDesktop>,
    );
    expect(screen.getByRole('main')).toHaveTextContent('Левая колонка');
    expect(screen.getByRole('complementary', { name: 'Контекст' })).toHaveTextContent('Правая колонка');
  });
});

describe('SubpageShell', () => {
  it('exposes a labelled actions footer', () => {
    render(
      <SubpageShell header={<PageHeader title="Настройки" />} actions={<button type="button">Сохранить</button>}>
        <p>Форма</p>
      </SubpageShell>,
    );
    expect(screen.getByRole('main')).toHaveTextContent('Форма');
    expect(screen.getByLabelText('Действия страницы')).toBeInTheDocument();
  });
});
