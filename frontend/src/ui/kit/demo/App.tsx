import { useState, type ReactNode } from 'react';
import { Icon } from '../icons/Icon';
import {
  ActionCard,
  AppShellDesktop,
  AppShellMobile,
  Avatar,
  Badge,
  BottomNav,
  BudgetBar,
  Button,
  Card,
  ChartBar,
  ChatOverlay,
  Checkbox,
  Chip,
  CommerceSeparatedFooter,
  ConnectionRow,
  ConsentRow,
  Dialog,
  Divider,
  EVOICard,
  EmptyState,
  ErrorState,
  Expander,
  IconButton,
  InboxItem,
  InboxList,
  Input,
  LoadingState,
  NotificationPreview,
  OfflineIndicator,
  PageHeader,
  PINPad,
  PortfolioSummary,
  Progress,
  RadioGroup,
  Ring,
  SafetyBand,
  Search,
  SectionHeader,
  Segmented,
  Select,
  Sheet,
  Skeleton,
  Spinner,
  SubpageShell,
  Switch,
  Textarea,
  Tile,
  TileGrid,
  Timeline,
  TimelineRow,
  Toast,
  UpdatePill,
} from '../ui';
import d from './demo.module.css';

function Section({ title, children, className }: { title: string; children: ReactNode; className?: string }) {
  return (
    <section className={`${d.section} ${className ?? ''}`}>
      <h2 className={d.sectionTitle}>{title}</h2>
      {children}
    </section>
  );
}

export function App() {
  const [viewport, setViewport] = useState<'mobile' | 'desktop'>('mobile');
  const [reminders, setReminders] = useState(true);
  const [consent, setConsent] = useState(true);
  const [agreement, setAgreement] = useState(false);
  const [sex, setSex] = useState('female');
  const [period, setPeriod] = useState('day');
  const [search, setSearch] = useState('');
  const [chip, setChip] = useState(true);
  const [pin, setPin] = useState('');
  const [dialogOpen, setDialogOpen] = useState(false);
  const [sheetOpen, setSheetOpen] = useState(false);
  const [chatOpen, setChatOpen] = useState(false);
  const [toastVisible, setToastVisible] = useState(true);
  const [messages, setMessages] = useState([
    { id: 'm1', role: 'assistant' as const, text: 'Здравствуйте. Чем помочь?' },
    { id: 'm2', role: 'user' as const, text: 'Что в плане на сегодня?' },
    { id: 'm3', role: 'assistant' as const, text: 'Прогулка 20 минут и дневник сна.' },
  ]);

  return (
    <main className={d.page}>
      <div className={d.toolbar}>
        <div>
          <p className={d.toolbarTitle}>Kubiki UI — семантическая галерея</p>
          <p className={d.toolbarNote}>
            Все компоненты используют токены, светлая тема, цели нажатия не меньше 44.
          </p>
        </div>
        <div className={d.viewportButtons} role="group" aria-label="Ширина галереи">
          <Button
            variant={viewport === 'mobile' ? 'primary' : 'secondary'}
            aria-pressed={viewport === 'mobile'}
            onClick={() => setViewport('mobile')}
          >
            390
          </Button>
          <Button
            variant={viewport === 'desktop' ? 'primary' : 'secondary'}
            aria-pressed={viewport === 'desktop'}
            onClick={() => setViewport('desktop')}
          >
            1200
          </Button>
        </div>
      </div>

      <div className={`${d.frame} ${viewport === 'mobile' ? d.frameMobile : d.frameDesktop}`}>
        <PageHeader
          title="Сегодня"
          subtitle="12 ноября · демо"
          onBack={() => undefined}
          action={
            <IconButton aria-label="Настройки">
              <Icon name="settings" />
            </IconButton>
          }
        />

        <div className={d.grid}>
          <Section title="Safety band" className={d.spanTwo}>
            <div className={d.column}>
              <SafetyBand variant="ok" title="Red flags: нет · safety: ок" />
              <SafetyBand variant="warning" title="Нужно внимание" >
                Проверьте данные профиля
              </SafetyBand>
              <SafetyBand variant="blocked" title="Сначала безопасность">
                Портфель скрыт до консультации
              </SafetyBand>
            </div>
          </Section>

          <Section title="Button">
            <div className={d.row}>
              <Button>Сделано</Button>
              <Button variant="accent">Подтвердить</Button>
              <Button variant="secondary">Перенести</Button>
              <Button variant="ghost">Пропустить</Button>
              <Button variant="danger">Эскалация</Button>
            </div>
            <div className={d.row}>
              <Button loading>Отправка</Button>
              <Button disabled>Недоступно</Button>
              <Button variant="secondary" leftIcon={<span>＋</span>}>
                Добавить
              </Button>
              <IconButton aria-label="Закрыть">×</IconButton>
            </div>
          </Section>

          <Section title="Fields">
            <Input label="Вес" unit="кг" defaultValue="84,2" hint="Шаг 0,1" />
            <Input label="Пульс" unit="уд/мин" error="Укажите значение" defaultValue="" />
            <Input label="Показатель" defaultValue="—" disabled hint="Недоступно для ввода" />
            <Textarea label="Заметка" hint="Без персональных данных" placeholder="Короткая запись" />
            <Select
              label="Период"
              placeholder="Выберите период"
              options={[
                { value: 'day', label: 'День' },
                { value: 'week', label: 'Неделя' },
                { value: 'month', label: 'Месяц' },
              ]}
            />
          </Section>

          <Section title="Контролы">
            <Switch
              label="Напоминания"
              description="Только внутри приложения"
              checked={reminders}
              onCheckedChange={setReminders}
            />
            <Switch label="Отключено" checked={false} disabled />
            <Checkbox
              label="Согласие на обработку"
              description="Можно отозвать в любой момент"
              checked={agreement}
              onChange={(event) => setAgreement(event.currentTarget.checked)}
            />
            <RadioGroup
              legend="Пол"
              name="demo-sex"
              value={sex}
              onChange={setSex}
              options={[
                { value: 'female', label: 'Женский' },
                { value: 'male', label: 'Мужской' },
                { value: 'unspecified', label: 'Не указывать' },
              ]}
            />
            <Segmented
              ariaLabel="Период"
              value={period}
              onChange={setPeriod}
              options={[
                { value: 'day', label: 'День' },
                { value: 'week', label: 'Неделя' },
                { value: 'month', label: 'Месяц' },
              ]}
            />
          </Section>

          <Section title="Chips, badges, avatar">
            <div className={d.row}>
              <Chip>unknown</Chip>
              <Chip>есть дома</Chip>
              <Chip as="button" selected={chip} onClick={() => setChip((value) => !value)}>
                Фильтр: есть
              </Chip>
            </div>
            <div className={d.row}>
              <Badge>нейтрально</Badge>
              <Badge tone="accent">ок</Badge>
              <Badge tone="warning">внимание</Badge>
              <Badge tone="danger">блок</Badge>
            </div>
            <div className={d.row}>
              <Avatar label="Пользователь" initials="АК" />
              <span>Анна К.</span>
              <Spinner />
            </div>
            <Search
              value={search}
              onChange={setSearch}
              onClear={() => setSearch('')}
              placeholder="Найти раздел"
            />
          </Section>

          <Section title="Card, divider, skeleton">
            <Card title="Карточка">
              <p>Содержимое карточки с обычным текстом.</p>
              <Divider />
              <div className={d.column} aria-hidden="true">
                <Skeleton variant="text" width="80%" />
                <Skeleton variant="rect" height="var(--space-6)" />
                <Skeleton variant="circle" width="var(--layout-tap)" height="var(--layout-tap)" />
              </div>
            </Card>
            <Progress label="Вода" value={14} min={0} max={20} valueText="1,4 / 2,0 л" />
            <Progress label="Внимание" value={70} tone="warning" valueText="на границе" />
          </Section>

          <Section title="Toast + status" className={d.spanTwo}>
            <div className={d.column}>
              {toastVisible && (
                <Toast title="Сохранено" tone="info" onClose={() => setToastVisible(false)}>
                  Изменения — это факт, не оценка.
                </Toast>
              )}
              <Toast title="Не удалось сохранить" tone="danger">
                Черновик остался в форме.
              </Toast>
              <Button variant="secondary" onClick={() => setToastVisible(true)}>
                Показать toast
              </Button>
            </div>
          </Section>

          <Section title="Action card" className={d.spanTwo}>
            <ActionCard
              title="Прогулка 20 мин"
              meta="20 мин · 0 ₽ · внимание низкое"
              why="Движение → цель «энергия» и «кардио-риск». Риск: колено — щадящий темп."
            >
              <Button>Сделано</Button>
              <Button variant="secondary">Перенести</Button>
              <Button variant="ghost">Пропустить</Button>
            </ActionCard>
            <Expander title="Почему это?">
              <p>Польза: умеренная. Уверенность: средняя. Без процентов.</p>
            </Expander>
          </Section>

          <Section title="Timeline">
            <SectionHeader title="Таймлайн дня" icon="calendar" action={<Badge tone="accent">4</Badge>} />
            <Timeline>
              <TimelineRow time="10:00" title="Прогулка" meta="20 мин · 0 ₽" icon={<Icon name="footsteps" />} />
              <TimelineRow time="14:00" title="Обед" meta="10 мин · ≈250 ₽" icon={<Icon name="utensils" />} />
              <TimelineRow time="23:00" title="Лечь до 23:30" meta="15 мин" icon={<Icon name="moon" />} />
            </Timeline>
          </Section>

          <Section title="Inbox">
            <SectionHeader title="Инбокс" icon="bell" action={<Badge tone="warning">2</Badge>} />
            <InboxList>
              <InboxItem title="Измерение АД" meta="не распределено" iconName="heart-pulse" />
              <InboxItem title="Дневник сна" meta="вчера unknown" iconName="moon" />
            </InboxList>
          </Section>

          <Section title="Бюджет дня">
            <BudgetBar
              period="сегодня"
              axes={[
                { label: 'Время', value: 20, max: 30, valueText: '2–3 ч / 3 ч', status: 'ok', statusText: 'влезает' },
                { label: 'Внимание', value: 6, max: 10, valueText: 'средне', status: 'warning', statusText: 'на границе' },
                { label: 'Деньги', value: 400, max: 600, valueText: '≈300–500 / 600', status: 'ok', statusText: 'влезает' },
              ]}
            />
            <PortfolioSummary
              active={4}
              max={5}
              deferred={2}
              excluded={1}
              reasons={['время', 'evidence', 'clinician']}
              note="Отложенные и исключённые видны с причиной."
            />
          </Section>

          <Section title="States">
            <EmptyState
              title="На сегодня действий нет"
              actions={
                <>
                  <Button variant="secondary">Проверить HPD</Button>
                  <Button variant="ghost">Пересобрать</Button>
                </>
              }
            >
              Причина: HPD не подтверждён. Пусто ≠ всё выполнено.
            </EmptyState>
            <ErrorState onRetry={() => undefined}>
              Портфель не изменён. Данные не потеряны.
            </ErrorState>
            <LoadingState label="Загрузка плана" rows={3} />
          </Section>

          <Section title="Dialog / sheet">
            <div className={d.row}>
              <Button onClick={() => setDialogOpen(true)}>Открыть диалог</Button>
              <Button variant="secondary" onClick={() => setSheetOpen(true)}>
                Открыть sheet
              </Button>
              <Button variant="ghost" onClick={() => setChatOpen(true)}>
                Помощник
              </Button>
            </div>
          </Section>

          <Section title="Tile + chart + ring" className={d.spanTwo}>
            <TileGrid>
              <Tile metric="4 / 5" title="Портфель" meta="отложено 2 · исключено 1" />
              <Tile metric="2–3 ч" title="Время" meta="из 3 ч" metricSize="sm" />
              <Tile metric="unknown" title="Сон" meta="вчера не указан" dark />
              <Tile wide metric="1 780–1 820" title="Калории" meta="ккал · диапазон" iconName="utensils" />
              <Tile metric="12" title="Шаги" meta="цель 8 000" soon dense />
              <Tile title="Вес" placeholder />
            </TileGrid>
            <div className={d.grid}>
              <ChartBar
                title="Дни недели"
                data={[
                  { label: 'Пн', value: 3 },
                  { label: 'Вт', value: 5 },
                  { label: 'Ср', value: 2, tone: 'carbs' },
                  { label: 'Чт', value: 4 },
                ]}
              />
              <div className={d.row}>
                <Ring label="Приверженность" value={3} max={5} valueText="3 из 5" />
                <Ring label="Вода" value={14} max={20} valueText="1,4 из 2,0 л" />
              </div>
            </div>
          </Section>

          <Section title="PIN">
            <PINPad value={pin} onChange={setPin} onComplete={() => undefined} />
            <p className={d.toolbarNote}>Ввод: цифры и Backspace с клавиатуры.</p>
          </Section>

          <Section title="Consent / connections">
            <ConsentRow
              title="Согласие на напоминания"
              description="Каналы можно изменить позже"
              checked={consent}
              onChange={setConsent}
            />
            <ConnectionRow
              title="HPD"
              description="Источник плана"
              status="ok"
              action={<Button variant="secondary">Открыть</Button>}
            />
            <ConnectionRow title="Синхронизация" status="warning" statusText="Требует подтверждения" />
            <ConnectionRow title="Устройство" status="unknown" />
          </Section>

          <Section title="Notification + commerce" className={d.spanTwo}>
            <NotificationPreview
              title="Напоминание"
              body="Пора внести запись в дневник."
              time="09:00"
            />
            <NotificationPreview
              app="Кубики здоровья"
              title="План обновлён"
              body="Откройте приложение, чтобы посмотреть детали."
            />
            <CommerceSeparatedFooter>
              <Button variant="secondary">Экспорт списка</Button>
            </CommerceSeparatedFooter>
          </Section>

          <Section title="EVOI-lite" className={d.spanTwo}>
            <EVOICard
              rows={[
                { label: 'Влияние решения', value: 'умеренное' },
                { label: 'Уверенность', value: 'средняя' },
                { label: 'Когда пересмотреть', value: 'через 2 недели' },
              ]}
              note="Диапазоны и ordinal, без ложной точности."
              actions={<Button variant="secondary">Понятно</Button>}
            />
          </Section>

          <Section title="Status + updates">
            <div className={d.row}>
              <OfflineIndicator />
              <UpdatePill onClick={() => undefined} />
            </div>
          </Section>

          <Section title="App shells" className={d.spanTwo}>
            <AppShellMobile
              contained
              header={<PageHeader title="Мобильный shell" subtitle="320–430" />}
              context={<OfflineIndicator label="Офлайн-режим" />}
              bottomNav={<BottomNav items={[{ id: 'home', label: 'Сегодня', iconName: 'heart-pulse', current: true }]} />}
            >
              <Tile metric="4 / 5" title="Портфель" meta="main-слот" />
            </AppShellMobile>
            <AppShellDesktop
              contained
              header={<PageHeader title="Desktop shell" subtitle="main 680 / context 448" />}
              context={<PortfolioSummary active={4} max={5} deferred={1} note="context-слот" />}
              bottomNav={null}
            >
              <Tile metric="2–3 ч" title="Время" meta="main-слот" metricSize="sm" />
            </AppShellDesktop>
            <SubpageShell
              contained
              header={<PageHeader title="Subpage shell" subtitle="sticky actions" />}
              actions={<Button variant="accent">Сохранить</Button>}
            >
              <p className={d.toolbarNote}>Контент подстраницы с нижней панелью действий.</p>
            </SubpageShell>
          </Section>
        </div>

        <Divider />
        <BottomNav
          items={[
            { id: 'food', label: 'Питание', iconName: 'utensils' },
            { id: 'vitamins', label: 'Витамины', iconName: 'pill', current: true },
            { id: 'more', label: 'Ещё', iconName: 'settings' },
          ]}
          assistantLabel="Помощник"
          onAssistant={() => setChatOpen(true)}
        />
      </div>

      <Dialog
        open={dialogOpen}
        onClose={() => setDialogOpen(false)}
        title="Почему это?"
        actions={
          <>
            <Button variant="secondary" onClick={() => setDialogOpen(false)}>
              Закрыть
            </Button>
            <Button onClick={() => setDialogOpen(false)}>Понятно</Button>
          </>
        }
      >
        <p>Польза: умеренная. Уверенность: средняя. Без процентов.</p>
        <p>Риск: при боли — остановиться.</p>
      </Dialog>

      <Sheet
        open={sheetOpen}
        onClose={() => setSheetOpen(false)}
        title="Отложенные и исключённые"
        actions={<Button onClick={() => setSheetOpen(false)}>Понятно</Button>}
      >
        <p>Сила 3×/нед — не влезает по времени.</p>
        <p>Дневник сна — конфликт с attention cap.</p>
      </Sheet>

      <ChatOverlay
        open={chatOpen}
        onClose={() => setChatOpen(false)}
        messages={messages}
        onSend={(text) =>
          setMessages((current) => [
            ...current,
            { id: `m${current.length + 1}`, role: 'user', text },
          ])
        }
      />
    </main>
  );
}
