import { describe, expect, it } from 'vitest';

import { tokens } from '../tokens';
import { contrastRatio, hexToRgb, meetsAA, relativeLuminance } from './contrast';

const c = tokens.color;

describe('WCAG helpers', () => {
  it('parses shorthand and 8-digit hex values', () => {
    expect(hexToRgb('#FFF')).toEqual([255, 255, 255]);
    expect(hexToRgb('#14141461')).toEqual([20, 20, 20]);
  });

  it('computes relative luminance and contrast for known pairs', () => {
    expect(relativeLuminance('#FFFFFF')).toBeCloseTo(1, 5);
    expect(relativeLuminance('#000000')).toBeCloseTo(0, 5);
    expect(contrastRatio('#FFFFFF', '#141414')).toBeCloseTo(18.42, 1);
    expect(contrastRatio('#8C8C8C', '#FFFFFF')).toBeCloseTo(3.36, 1);
  });

  it('applies AA thresholds for normal and large text', () => {
    expect(meetsAA(4.5)).toBe(true);
    expect(meetsAA(4.49)).toBe(false);
    expect(meetsAA(3, true)).toBe(true);
    expect(meetsAA(2.99, true)).toBe(false);
  });
});

describe('palette contrast (computed)', () => {
  it.each([
    ['primary: white on dark surface', c['text-on-dark'], c['dark-surface']],
    ['accent base: accent ink on accent', c['accent-ink'], c.accent],
    ['accent hover: white on accent-hover', c['text-on-dark'], c['accent-hover']],
    ['accent pressed: white on accent-pressed', c['text-on-dark'], c['accent-pressed']],
    ['danger: dark surface on danger', c['dark-surface'], c.danger],
    ['secondary text on bg', c['text-secondary'], c.bg],
    ['secondary text on white', c['text-secondary'], c.surface],
    ['muted text on bg', c['text-muted'], c.bg],
    ['muted text on white', c['text-muted'], c.surface],
    ['warning text on warning soft', c['warning-strong'], c['warning-soft']],
    ['success text on success soft', c['success-strong'], c['success-soft']],
  ])('%s is >= 4.5:1', (_name, foreground, background) => {
    expect(contrastRatio(foreground, background)).toBeGreaterThanOrEqual(4.5);
  });

  it('never places white text on the base accent (#1DAF61)', () => {
    const ratio = contrastRatio(c['text-on-dark'], c.accent);
    expect(ratio).toBeLessThan(4.5);
    // The canonical base pair uses accent-ink instead.
    expect(contrastRatio(c['accent-ink'], c.accent)).toBeGreaterThanOrEqual(4.5);
  });

  it('only allows tertiary text on dark surfaces or large sizes', () => {
    // Tertiary is below AA for body-size text on light surfaces.
    expect(contrastRatio(c['text-tertiary'], c.surface)).toBeLessThan(4.5);
    expect(contrastRatio(c['text-tertiary'], c.bg)).toBeLessThan(4.5);
    // On the dark surface it is readable enough for large/decorative text.
    expect(contrastRatio(c['text-tertiary'], c['dark-surface'])).toBeGreaterThanOrEqual(4.5);
  });
});
