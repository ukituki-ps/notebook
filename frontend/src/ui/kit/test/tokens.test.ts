import fs from 'node:fs';
import path from 'node:path';
import { describe, expect, it } from 'vitest';

const root = process.cwd();
const srcDir = path.join(root, 'src');

function walk(dir: string): string[] {
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const full = path.join(dir, entry.name);
    return entry.isDirectory() ? walk(full) : [full];
  });
}

const moduleCssFiles = walk(srcDir).filter((file) => file.endsWith('.module.css'));

describe('token contract', () => {
  it('src/styles/tokens.css is byte-identical to ../code/tokens.css', () => {
    const local = fs.readFileSync(path.join(root, 'src/styles/tokens.css'));
    const source = fs.readFileSync(path.join(root, '../code/tokens.css'));
    expect(local.equals(source)).toBe(true);
  });

  it('src/tokens.ts is byte-identical to ../code/tokens.ts', () => {
    const local = fs.readFileSync(path.join(root, 'src/tokens.ts'));
    const source = fs.readFileSync(path.join(root, '../code/tokens.ts'));
    expect(local.equals(source)).toBe(true);
  });

  it('has at least one CSS module to audit', () => {
    expect(moduleCssFiles.length).toBeGreaterThan(0);
  });

  it('contains no literal hex colors in CSS modules', () => {
    const offenders: string[] = [];
    for (const file of moduleCssFiles) {
      const text = fs.readFileSync(file, 'utf8');
      const matches = text.match(/#[0-9a-fA-F]{3,8}\b/g);
      if (matches) offenders.push(`${path.relative(root, file)}: ${matches.join(', ')}`);
    }
    expect(offenders).toEqual([]);
  });

  it('contains no rgb()/hsl() literals in CSS modules', () => {
    const offenders = moduleCssFiles.filter((file) => /\b(rgb|rgba|hsl|hsla)\(/.test(fs.readFileSync(file, 'utf8')));
    expect(offenders.map((file) => path.relative(root, file))).toEqual([]);
  });

  it('does not reuse the non-semantic HTML snapshots', () => {
    const files = walk(srcDir).filter(
      (file) => /\.(tsx|ts)$/.test(file) && !file.includes('.test.') && !file.includes('/test/'),
    );
    const offenders = files.filter((file) => fs.readFileSync(file, 'utf8').includes('dangerouslySetInnerHTML'));
    expect(offenders.map((file) => path.relative(root, file))).toEqual([]);
  });

  it('contains no px values except 1px (and 0)', () => {
    const offenders: string[] = [];
    for (const file of moduleCssFiles) {
      const text = fs.readFileSync(file, 'utf8');
      for (const match of text.matchAll(/(-?\d*\.?\d+)px/g)) {
        const value = Number(match[1]);
        if (value !== 1 && value !== 0) {
          offenders.push(`${path.relative(root, file)}: ${match[0]}`);
        }
      }
    }
    expect(offenders).toEqual([]);
  });
});

describe('tertiary text restriction', () => {
  it('does not use text-tertiary as a small text color', () => {
    const largeSizeTokens = new Set(['--fs-display', '--fs-h1']);
    const offenders: string[] = [];
    for (const file of moduleCssFiles) {
      const text = fs.readFileSync(file, 'utf8');
      for (const match of text.matchAll(/([^{}]+)\{([^{}]*)\}/g)) {
        const selector = match[1].trim();
        const body = match[2];
        if (!/(^|[;\s])color:\s*var\(--color-text-tertiary\)/.test(body)) continue;
        const sizeMatch = body.match(/font-size:\s*([^;]+);/);
        let isLarge = false;
        if (sizeMatch) {
          const value = sizeMatch[1].trim();
          const px = value.match(/^([\d.]+)px$/);
          if (px) isLarge = Number(px[1]) >= 24;
          const varName = value.match(/^var\((--[\w-]+)\)$/);
          if (varName) isLarge = largeSizeTokens.has(varName[1]);
        }
        if (!isLarge) offenders.push(`${path.relative(root, file)} ${selector}`);
      }
    }
    expect(offenders).toEqual([]);
  });

  it('uses muted (not tertiary) for the input placeholder and notification time', () => {
    const uiCss = fs.readFileSync(path.join(srcDir, 'ui/ui.module.css'), 'utf8');
    const p2Css = fs.readFileSync(path.join(srcDir, 'ui/p2.module.css'), 'utf8');
    expect(uiCss.match(/\.control::placeholder\s*\{([^}]*)\}/)![1]).toMatch(
      /color:\s*var\(--color-text-muted\)/,
    );
    expect(p2Css.match(/\.notificationTime\s*\{([^}]*)\}/)![1]).toMatch(
      /color:\s*var\(--color-text-muted\)/,
    );
  });
});

describe('target alias layer', () => {
  const css = fs.readFileSync(path.join(root, 'src/styles/tokens.css'), 'utf8');
  const declarations = new Map<string, string>();
  for (const match of css.matchAll(/^\s*(--[\w-]+):\s*([^;]+);/gm)) {
    declarations.set(match[1], match[2].trim());
  }
  const resolveCssValue = (name: string, seen = new Set<string>()): string | undefined => {
    const value = declarations.get(name);
    if (value === undefined) return undefined;
    const ref = value.match(/^var\((--[\w-]+)\)$/);
    if (!ref) return value;
    if (seen.has(name)) return value;
    seen.add(name);
    return resolveCssValue(ref[1], seen);
  };

  it.each([
    ['--color-accent-ink', '#06331C'],
    ['--color-accent-hover', '#12703F'],
    ['--color-accent-pressed', '#0F6B3B'],
    ['--divider', '#F4F1EC'],
    ['--surface-overlay', '#14141461'],
    ['--surface-card', '#FFFFFF'],
    ['--surface-sunken', '#F4F0EA'],
    ['--surface-success-soft', '#E4F5EC'],
    ['--surface-warning-soft', '#FEEBDF'],
    ['--surface-accent-soft', '#DFF4E9'],
    ['--text-primary', '#141414'],
    ['--text-secondary', '#575757'],
    ['--text-muted', '#6A6A6A'],
    ['--text-tertiary', '#8C8C8C'],
    ['--text-warning', '#AA5217'],
    ['--accent', '#1DAF61'],
    ['--accent-strong', '#178C4E'],
    ['--danger', '#FA7319'],
    ['--chart-bar', '#1DAF61'],
    ['--chart-grid', '#F4F1EC'],
    ['--chart-axis', '32px'],
    ['--chart-col-max', '48px'],
    ['--chart-h', '180px'],
    ['--chart-gap', '6px'],
    ['--chart-bar-max', '28px'],
    ['--chart-bar-radius', '6px'],
    ['--chart-bar-min-h', '4px'],
    ['--empty-icon-size', '44px'],
    ['--card-icon-size', '28px'],
    ['--fs-chart-label', '10px'],
    ['--tap-min', '44px'],
    ['--page-gutter', '18px'],
    ['--tile-gap', '12px'],
    ['--content-max', '480px'],
    ['--header-h', '56px'],
    ['--bottom-nav-h', '84px'],
    ['--sticky-actions-h', '64px'],
    ['--dur-fast', '120ms'],
    ['--dur-base', '200ms'],
    ['--dur-slow', '320ms'],
    ['--shadow-raised', '0 12px 32px -16px #14141447'],
    ['--shadow-fab', '0 10px 24px -10px #1DAF618C'],
    ['--shadow-nav', '0 8px 22px -12px #14141459'],
    ['--shadow-tile', 'inset 0 0 0 1px #EFE9E1'],
    ['--ring-inset', 'inset 0 0 0 1px #EFE9E1'],
    ['--text-success', '#178048'],
    ['--expander-link', '#141414'],
    ['--control-height', '48px'],
    ['--control-radius', '14px'],
    ['--pin-key', '64px'],
  ])('defines %s with %s', (name, value) => {
    expect(resolveCssValue(name)).toBe(value);
  });

  it('emits every kh_pg target compatibility alias (50 names)', () => {
    const targetNames = [
      '--accent',
      '--accent-strong',
      '--balance-carbs',
      '--balance-fat',
      '--balance-protein',
      '--bottom-nav-h',
      '--carbs',
      '--card-icon-size',
      '--chart-bar-max',
      '--chart-bar-min-h',
      '--chart-bar-radius',
      '--chart-gap',
      '--chart-h',
      '--color-card-ring',
      '--color-green-ink',
      '--color-green-primary',
      '--color-orange-fat',
      '--content-max',
      '--danger',
      '--fat',
      '--fw-bold',
      '--fw-medium',
      '--fw-regular',
      '--fw-semibold',
      '--header-h',
      '--lh-normal',
      '--lh-snug',
      '--lh-tight',
      '--ls-label',
      '--ls-title',
      '--mint-carbs',
      '--protein',
      '--ring-color',
      '--shadow-tile',
      '--sticky-actions-h',
      '--surface-accent-soft',
      '--surface-card',
      '--surface-draft-soft',
      '--surface-success-soft',
      '--surface-sunken',
      '--surface-warning-soft',
      '--text-draft',
      '--text-muted',
      '--text-on-dark',
      '--text-on-dark-muted',
      '--text-primary',
      '--text-secondary',
      '--text-tertiary',
      '--text-warning',
      '--tile-gap',
    ];
    const missing = targetNames.filter((name) => !css.includes(`${name}:`));
    expect(missing).toEqual([]);
    expect(targetNames).toHaveLength(50);
  });
});

describe('canonical button + expander contract', () => {
  const ui = fs.readFileSync(path.join(srcDir, 'ui/ui.module.css'), 'utf8');
  const patterns = fs.readFileSync(path.join(srcDir, 'ui/patterns.module.css'), 'utf8');

  it('base button is 48px tall with radius 14', () => {
    const block = ui.match(/\.button\s*\{([^}]*)\}/)![1];
    expect(block).toMatch(/min-height:\s*var\(--control-height\)/);
    expect(block).toMatch(/border-radius:\s*var\(--control-radius\)/);
  });

  it('primary uses dark surface + white text', () => {
    const block = ui.match(/\.primary\s*\{([^}]*)\}/)![1];
    expect(block).toMatch(/background:\s*var\(--color-dark-surface\)/);
    expect(block).toMatch(/color:\s*var\(--color-text-on-dark\)/);
  });

  it('accent uses #1DAF61 background + accent-ink text', () => {
    const block = ui.match(/\.accent\s*\{([^}]*)\}/)![1];
    expect(block).toMatch(/background:\s*var\(--color-accent\)/);
    expect(block).toMatch(/color:\s*var\(--color-accent-ink\)/);
  });

  it('accent hover/pressed switch to dark backgrounds + white text', () => {
    const hover = ui.match(/\.accent:hover[^{]*\{([^}]*)\}/)![1];
    const active = ui.match(/\.accent:active[^{]*\{([^}]*)\}/)![1];
    expect(hover).toMatch(/background:\s*var\(--color-accent-hover\)/);
    expect(hover).toMatch(/color:\s*var\(--color-text-on-dark\)/);
    expect(active).toMatch(/background:\s*var\(--color-accent-pressed\)/);
    expect(active).toMatch(/color:\s*var\(--color-text-on-dark\)/);
  });

  it('expander trigger uses the expander-link token', () => {
    const block = patterns.match(/\.expanderButton\s*\{([^}]*)\}/)![1];
    expect(block).toMatch(/color:\s*var\(--color-expander-link\)/);
  });
});

describe('touch-target audit', () => {
  const interactive = [
    ['ui.module.css', 'button', '--control-height'],
    ['ui.module.css', 'iconButton', '--layout-tap'],
    ['ui.module.css', 'control', '--layout-tap'],
    ['ui.module.css', 'segment', '--layout-tap'],
    ['ui.module.css', 'switchRow', '--control-height'],
    ['ui.module.css', 'switchControl', '--layout-tap'],
    ['ui.module.css', 'checkRow', '--control-height'],
    ['ui.module.css', 'radioRow', '--control-height'],
    ['ui.module.css', 'chipButton', '--layout-tap'],
    ['ui.module.css', 'searchClear', '--layout-tap'],
    ['patterns.module.css', 'pageHeaderBack', '--layout-tap'],
    ['patterns.module.css', 'inboxItem', '--control-height'],
    ['patterns.module.css', 'timelineRow', '--control-height'],
    ['patterns.module.css', 'expanderButton', '--control-height'],
    ['patterns.module.css', 'bottomNavItem', '--layout-tap'],
    ['p2.module.css', 'tile', '--control-height'],
    ['p2.module.css', 'pinKey', '--pin-key'],
    ['p2.module.css', 'rowCard', '--control-height'],
    ['feedback.module.css', 'offline', '--control-height'],
    ['feedback.module.css', 'updatePill', '--layout-tap'],
    ['shells.module.css', 'actions', '--control-height'],
  ] as const;

  it.each(interactive)('%s > .%s is at least var(%s) tall', (file, selector, token) => {
    const text = fs.readFileSync(path.join(srcDir, 'ui', file), 'utf8');
    const block = text.match(new RegExp(`\\.${selector}\\s*\\{([^}]*)\\}`));
    expect(block, `missing .${selector} rule in ${file}`).not.toBeNull();
    expect(block![1]).toMatch(new RegExp(`(min-height|height):\\s*var\\(${token}\\)`));
  });
});
