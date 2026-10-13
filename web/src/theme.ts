// Thèmes par cause, lus directement dans design/tokens.json (source de vérité).
import tokens from '../../design/tokens.json';
import type { CauseId } from './api';

export interface CauseTheme {
  id: CauseId;
  label: string;
  icon: string;
  primary: string;
  deep: string;
  soft: string;
  mid: string;
  pop: string;
  stripe: string[];
}

const causes = tokens.causes as Record<CauseId, Omit<CauseTheme, 'id'>>;

export const CAUSES: CauseTheme[] = (Object.keys(causes) as CauseId[]).map((id) => ({
  id,
  ...causes[id],
}));

export function cause(id: CauseId): CauseTheme {
  return CAUSES.find((c) => c.id === id) ?? CAUSES[CAUSES.length - 1];
}

/** Variables CSS d'une cause, à poser sur un conteneur. */
export function causeVars(id: CauseId): string {
  const c = cause(id);
  const n = c.stripe.length;
  const stops = c.stripe
    .map((color, i) => `${color} ${((i / n) * 100).toFixed(1)}% ${(((i + 1) / n) * 100).toFixed(1)}%`)
    .join(', ');
  return [
    `--primary:${c.primary}`,
    `--deep:${c.deep}`,
    `--soft:${c.soft}`,
    `--mid:${c.mid}`,
    `--pop:${c.pop}`,
    `--stripe:linear-gradient(90deg, ${stops})`,
  ].join(';');
}

// Icônes de cause, mêmes tracés que les maquettes
export const CAUSE_ICONS: Record<string, string> = {
  leaf: 'M5 19c0-8 5-14 15-14 0 10-6 15-14 15|M5 19c3-4 6-7 10-9',
  rainbow: 'M2 18a10 10 0 0 1 20 0|M6 18a6 6 0 0 1 12 0|M10 18a2 2 0 0 1 4 0',
  peace: 'M12 3a9 9 0 1 0 0 18a9 9 0 1 0 0-18|M12 3v18M12 12l-6.4 6.4M12 12l6.4 6.4',
  megaphone: 'M3 10v4h3l8 4.5V5.5L6 10H3z|M17.5 9a4 4 0 0 1 0 6',
  cross: 'M9.5 3.5h5v6h6v5h-6v6h-5v-6h-6v-5h6z',
  graduation: 'M2 9l10-5 10 5-10 5z|M6 11v5c3 2 9 2 12 0v-5',
  flag: 'M5 21V4M5 4h11l-2 4 2 4H5',
};
