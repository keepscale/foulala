import logoUrl from '../../design/logo.svg';
import { h, icon, ICONS } from './dom';
import { logout, session } from './api';

export { logoUrl };

export function logo(size = 32): HTMLElement {
  return h('span', { class: 'brand' },
    h('img', { src: logoUrl, width: Math.round(size * 1.14), height: size, alt: '' }),
    h('span', { class: 'wordmark' }, 'fou', h('span', { class: 'lala' }, 'lala')),
  );
}

export function header(): HTMLElement {
  const s = session();
  return h('header', { class: 'topbar' },
    h('div', { class: 'topbar-inner' },
      h('a', { href: '#/', class: 'brand-link', 'aria-label': 'Foulala, mes manifestations' }, logo(),
        h('span', { class: 'topbar-sub' }, 'Espace organisateur')),
      s && h('div', { class: 'account' },
        h('span', { class: 'avatar', 'aria-hidden': 'true' }, initials(s.name)),
        h('span', { class: 'account-name' }, s.name),
        h('a', { href: '#/mot-de-passe', class: 'btn btn-ghost' }, icon(ICONS.key), 'Mot de passe'),
        h('button', {
          type: 'button', class: 'btn btn-ghost', onclick: () => {
            logout();
            location.hash = '#/connexion';
          },
        }, icon(ICONS.logout), 'Se déconnecter'),
      ),
    ),
  );
}

function initials(name: string): string {
  return name.split(/\s+/).filter((w) => w.length > 2 || /^[A-ZÉ]/.test(w)).slice(0, 2)
    .map((w) => w[0].toUpperCase()).join('') || name.slice(0, 2).toUpperCase();
}

/** Message d'erreur ou d'information, annoncé aux lecteurs d'écran. */
export function notice(kind: 'error' | 'info', text: string): HTMLElement {
  return h('p', { class: `notice notice-${kind}`, role: kind === 'error' ? 'alert' : 'status' }, text);
}

const dateFmt = new Intl.DateTimeFormat('fr-FR', { weekday: 'short', day: 'numeric', month: 'short', year: 'numeric' });
const timeFmt = new Intl.DateTimeFormat('fr-FR', { hour: '2-digit', minute: '2-digit' });

export function formatWhen(startIso: string, endIso: string): string {
  const s = new Date(startIso);
  const e = new Date(endIso);
  const sameDay = s.toDateString() === e.toDateString();
  return sameDay
    ? `${dateFmt.format(s)} · ${timeFmt.format(s)} – ${timeFmt.format(e)}`
    : `${dateFmt.format(s)} ${timeFmt.format(s)} → ${dateFmt.format(e)} ${timeFmt.format(e)}`;
}

export function formatCount(n: number | null | undefined): string {
  return new Intl.NumberFormat('fr-FR').format(n ?? 0);
}
