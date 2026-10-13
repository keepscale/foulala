import { h, icon, ICONS } from './dom';
import { ApiError, logout, session } from './api';
import { logo, notice } from './layout';

export type AdminTab = 'pilotage' | 'manifs' | 'collectifs' | 'journal';

const TABS: { id: AdminTab; href: string; label: string }[] = [
  { id: 'pilotage', href: '#/admin', label: 'Pilotage' },
  { id: 'manifs', href: '#/admin/manifs', label: 'Manifestations' },
  { id: 'collectifs', href: '#/admin/collectifs', label: 'Collectifs' },
  { id: 'journal', href: '#/admin/journal', label: 'Journal' },
];

const timeFmt = new Intl.DateTimeFormat('fr-FR', { hour: '2-digit', minute: '2-digit' });

/** En-tête de l'administration : bandeau sombre, pour ne jamais la confondre avec l'espace organisateur. */
export function adminHeader(active: AdminTab): HTMLElement {
  const s = session('admin');
  return h('header', { class: 'topbar topbar-admin' },
    h('div', { class: 'topbar-inner' },
      h('a', { href: '#/admin', class: 'brand-link', 'aria-label': 'Foulala, pilotage' }, logo(),
        h('span', { class: 'topbar-sub' }, icon(ICONS.shield, 16), 'Administration')),
      s && h('div', { class: 'account' },
        h('span', { class: 'account-name' }, s.name),
        h('span', { class: 'small session-end' }, `session jusqu'à ${timeFmt.format(new Date(s.expires_at))}`),
        h('button', {
          type: 'button', class: 'btn btn-ghost', onclick: () => {
            logout('admin');
            location.hash = '#/admin/connexion';
          },
        }, icon(ICONS.logout), 'Se déconnecter'),
      ),
    ),
    h('nav', { class: 'admin-tabs', 'aria-label': 'Administration' },
      h('div', { class: 'admin-tabs-inner' },
        TABS.map((t) => h('a', {
          href: t.href, class: 'admin-tab', 'aria-current': t.id === active ? 'page' : undefined,
        }, t.label)),
      ),
    ),
  );
}

/** Mise en page commune : en-tête, titre, zone de messages, contenu. */
export function adminPage(
  root: HTMLElement, active: AdminTab, title: string, intro: string, ...content: HTMLElement[]
): HTMLElement {
  const messages = h('div', { 'aria-live': 'polite', class: 'messages' });
  root.replaceChildren(
    adminHeader(active),
    h('main', { class: 'container' },
      h('div', { class: 'page-head' },
        h('div', {}, h('h1', {}, title), h('p', { class: 'muted' }, intro)),
      ),
      messages,
      ...content,
    ),
  );
  return messages;
}

/** Exécute une action et affiche le résultat dans [messages]. */
export async function runAction(
  messages: HTMLElement, done: string, fn: () => Promise<void>, reload: () => Promise<void>,
): Promise<boolean> {
  messages.replaceChildren();
  try {
    await fn();
    messages.append(notice('info', done));
    await reload();
    return true;
  } catch (e) {
    messages.append(notice('error', errorText(e)));
    return false;
  }
}

export function errorText(e: unknown): string {
  return e instanceof ApiError ? e.message : 'Action impossible.';
}

/**
 * Petit formulaire « motif » qui se déplie sous une ligne, à la place d'une boîte de dialogue.
 * Le motif est obligatoire (5 caractères au moins) : le collectif le lira.
 */
export function reasonForm(opts: {
  label: string;
  placeholder: string;
  submit: string;
  onSubmit: (reason: string) => Promise<boolean>;
  onCancel: () => void;
}): HTMLElement {
  const id = `reason-${Math.random().toString(36).slice(2)}`;
  const input = h('textarea', { id, rows: 2, maxlength: 500, placeholder: opts.placeholder, required: true });
  const error = h('div', { 'aria-live': 'polite' });
  const button = h('button', { type: 'submit', class: 'btn btn-danger btn-sm' }, opts.submit);
  const form = h('form', {
    class: 'reason-form',
    onsubmit: async (ev: Event) => {
      ev.preventDefault();
      error.replaceChildren();
      const reason = input.value.trim();
      if (reason.length < 5) {
        error.append(notice('error', 'Indiquez un motif d\'au moins 5 caractères : le collectif le lira.'));
        input.focus();
        return;
      }
      button.disabled = true;
      if (!(await opts.onSubmit(reason))) button.disabled = false;
    },
  },
    h('label', { for: id }, opts.label),
    input,
    error,
    h('div', { class: 'actions' },
      button,
      h('button', { type: 'button', class: 'btn btn-ghost btn-sm', onclick: opts.onCancel }, 'Annuler'),
    ),
  );
  queueMicrotask(() => input.focus());
  return form;
}

/** Mot de passe provisoire, montré une seule fois, avec un bouton pour le copier. */
export function secretBox(title: string, who: string, password: string): HTMLElement {
  const copy = h('button', {
    type: 'button', class: 'btn btn-soft btn-sm',
    onclick: async () => {
      try {
        await navigator.clipboard.writeText(password);
        copy.replaceChildren(icon(ICONS.check), 'Copié');
      } catch {
        copy.replaceChildren('Copie impossible : sélectionnez le texte');
      }
    },
  }, icon(ICONS.copy), 'Copier');
  return h('div', { class: 'secret-box', role: 'status' },
    h('p', {}, h('strong', {}, title)),
    h('p', { class: 'small' }, who),
    h('div', { class: 'secret-row' }, h('code', { class: 'secret' }, password), copy),
    h('p', { class: 'small' },
      'Affiché une seule fois. Transmettez-le par un canal sûr (pas le même que l\'e-mail), ',
      'et demandez au collectif de le changer dès sa première connexion.'),
  );
}

export function formatDateTime(iso: string | null | undefined): string {
  if (!iso) return '—';
  return new Intl.DateTimeFormat('fr-FR', {
    day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit',
  }).format(new Date(iso));
}
