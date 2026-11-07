/**
 * WCAG 2.x relative luminance and contrast-ratio helpers.
 *
 * https://www.w3.org/TR/WCAG21/#dfn-relative-luminance
 * https://www.w3.org/TR/WCAG21/#dfn-contrast-ratio
 *
 * Supports #RGB, #RRGGBB and #RRGGBBAA (alpha is ignored, as the palette
 * pairs below are opaque foreground/background combinations).
 */

export type Rgb = readonly [number, number, number];

export function normalizeHex(hex: string): string {
  const value = hex.trim().replace(/^#/, '');
  if (value.length === 3) {
    return value
      .split('')
      .map((channel) => channel + channel)
      .join('');
  }
  if (value.length === 6 || value.length === 8) return value.slice(0, 6);
  throw new Error(`Unsupported hex color: ${hex}`);
}

export function hexToRgb(hex: string): Rgb {
  const value = normalizeHex(hex);
  return [
    Number.parseInt(value.slice(0, 2), 16),
    Number.parseInt(value.slice(2, 4), 16),
    Number.parseInt(value.slice(4, 6), 16),
  ] as const;
}

function linearize(channel: number): number {
  const normalized = channel / 255;
  return normalized <= 0.03928
    ? normalized / 12.92
    : ((normalized + 0.055) / 1.055) ** 2.4;
}

export function relativeLuminance(hex: string): number {
  const [r, g, b] = hexToRgb(hex);
  return 0.2126 * linearize(r) + 0.7152 * linearize(g) + 0.0722 * linearize(b);
}

export function contrastRatio(foreground: string, background: string): number {
  const a = relativeLuminance(foreground);
  const b = relativeLuminance(background);
  const lighter = Math.max(a, b);
  const darker = Math.min(a, b);
  return (lighter + 0.05) / (darker + 0.05);
}

/** WCAG AA: 4.5:1 for normal text, 3:1 for large text. */
export function meetsAA(ratio: number, large = false): boolean {
  return ratio >= (large ? 3 : 4.5);
}
