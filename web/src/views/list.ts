import { h, icon, ICONS } from '../dom';
import { api, ApiError, type MyEvent } from '../api';
import { cause, causeVars, CAUSE_ICONS } from '../theme';
import { formatCount, formatWhen, header, notice } from '../layout';

const STATUS_LABEL: Record<string, string> = {
  draft: 'Brouillon',
  published: 'Publiée',
  cancelled: 'Annulée',
  ended: 'Terminée',
};

export async function listView(root: HTMLElement): Promise<void> {
  const messages = h('div', { 'aria-live': 'polite' });
  const list = h('div', { class: 'event-list' }, h('p', { class: 'muted' }, 'Chargement…'));

  root.replaceChildren(
    header(),
    h('main', { class: 'container' },
      h('div', { class: 'page-head' },
        h('div', {},
          h('h1', {}, 'Mes manifestations'),
          h('p', { class: 'muted' }, 'Un brouillon reste invisible. Une fois publiée, la manif apparaît dans l\'app et le comptage peut commencer.'),
        ),
        h('a', { href: '#/nouvelle', class: 'btn btn-primary' }, icon(ICONS.plus), 'Nouvelle manifestation'),
      ),
      messages,
      list,
    ),
  );

  async function load(): Promise<void> {
    try {
      const events = await api.myEvents();
      if (!events.length) {
        list.replaceChildren(h('div', { class: 'empty' },
          h('p', {}, 'Aucune manifestation pour l\'instant.'),
          h('a', { href: '#/nouvelle', class: 'btn btn-primary' }, icon(ICONS.plus), 'Déclarer ma première manif'),
        ));
        return;
      }
      list.replaceChildren(...events.map(card));
    } catch (e) {
      list.replaceChildren(notice('error', e instanceof ApiError ? e.message : 'Chargement impossible.'));
    }
  }

  async function act(label: string, fn: () => Promise<void>): Promise<void> {
    messages.replaceChildren();
    try {
      await fn();
      messages.append(notice('info', label));
      await load();
    } catch (e) {
      messages.append(notice('error', e instanceof ApiError ? e.message : 'Action impossible.'));
    }
  }

  function card(ev: MyEvent): HTMLElement {
    const c = cause(ev.cause);
    const ended = new Date(ev.ends_at).getTime() < Date.now();
    const statusKey = ev.status === 'published' && ended ? 'ended' : ev.status;

    const actions: HTMLElement[] = [];
    if (ev.status === 'draft') {
      actions.push(
        h('a', { href: `#/manif/${ev.id}`, class: 'btn btn-soft' }, icon(ICONS.pen), 'Modifier'),
        h('button', {
          type: 'button', class: 'btn btn-primary', disabled: ended,
          title: ended ? 'Cette manif est déjà terminée' : undefined,
          onclick: () => {
            if (confirm(`Publier « ${ev.title} » ?\n\nElle sera visible dans l'app. Le parcours et les horaires ne pourront plus être modifiés.`)) {
              void act('Manifestation publiée.', () => api.publish(ev.id));
            }
          },
        }, 'Publier'),
        h('button', {
          type: 'button', class: 'btn btn-ghost',
          onclick: () => {
            if (confirm(`Supprimer le brouillon « ${ev.title} » ?`)) {
              void act('Brouillon supprimé.', () => api.deleteDraft(ev.id));
            }
          },
        }, icon(ICONS.trash), 'Supprimer'),
      );
    } else {
      actions.push(h('a', { href: `#/manif/${ev.id}`, class: 'btn btn-soft' }, 'Voir'));
      if (ev.status === 'published' && !ended) {
        actions.push(h('button', {
          type: 'button', class: 'btn btn-ghost',
          onclick: () => {
            if (confirm(`Annuler « ${ev.title} » ?\n\nElle restera visible, marquée « annulée ». Ce choix est définitif.`)) {
              void act('Manifestation annulée.', () => api.cancel(ev.id));
            }
          },
        }, 'Annuler la manif'));
      }
    }

    return h('article', { class: 'event-card', style: causeVars(ev.cause) },
      h('div', { class: 'event-icon', 'aria-hidden': 'true' }, icon(CAUSE_ICONS[c.icon] ?? CAUSE_ICONS.flag, 26)),
      h('div', { class: 'event-body' },
        h('div', { class: 'chips' },
          h('span', { class: 'chip chip-cause' }, c.label),
          h('span', { class: `chip status status-${statusKey}` }, STATUS_LABEL[statusKey]),
          ev.declared && h('span', { class: 'chip chip-outline' }, icon(ICONS.check, 14), 'Déclarée'),
          ev.hidden_at && h('span', { class: 'chip status-hidden' }, icon(ICONS.eyeOff, 14), 'Masquée par Foulala'),
        ),
        h('h2', {}, ev.title),
        h('p', { class: 'muted' }, `${formatWhen(ev.starts_at, ev.ends_at)} · ${ev.city}`),
        ev.status !== 'draft' && h('p', { class: 'counts' },
          h('strong', {}, formatCount(ev.present)), ' présents vérifiés · ',
          h('strong', {}, formatCount(ev.supporters)), ' soutiens'),
        ev.hidden_at && h('p', { class: 'moderation-note' },
          h('strong', {}, 'Retirée de l\'app par la modération : '), ev.hidden_reason ?? '',
          h('br'), 'Pour contester, écrivez à l\'équipe de Foulala.'),
      ),
      h('div', { class: 'event-actions' }, actions),
    );
  }

  await load();
}
