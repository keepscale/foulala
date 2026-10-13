import { h, icon, ICONS } from '../../dom';
import { adminApi, type AdminEvent } from '../../api';
import { cause, causeVars, CAUSE_ICONS } from '../../theme';
import { formatCount, formatWhen, notice } from '../../layout';
import { adminPage, errorText, formatDateTime, reasonForm, runAction } from '../../admin-layout';

type Filter = 'all' | 'visible' | 'live' | 'hidden';

/** Modération : toutes les manifs publiées ou annulées, de tous les collectifs. */
export async function adminEventsView(root: HTMLElement): Promise<void> {
  const search = h('input', { id: 'search', type: 'text', placeholder: 'Titre, ville ou collectif', autocomplete: 'off' });
  const filter = h('select', { id: 'filter' },
    h('option', { value: 'all' }, 'Toutes'),
    h('option', { value: 'visible' }, 'Visibles dans l\'app'),
    h('option', { value: 'live' }, 'En cours'),
    h('option', { value: 'hidden' }, 'Masquées'),
  );
  const count = h('p', { class: 'small muted', 'aria-live': 'polite' });
  const list = h('div', { class: 'event-list' }, h('p', { class: 'muted' }, 'Chargement…'));

  const messages = adminPage(root, 'manifs', 'Manifestations',
    'Masquer une manif la retire de l\'app et bloque les nouveaux « J\'y suis ! » et soutiens. Le collectif voit le motif. Les brouillons restent privés.',
    h('div', { class: 'filters' },
      h('div', { class: 'field' }, h('label', { for: 'search' }, 'Rechercher'), search),
      h('div', { class: 'field' }, h('label', { for: 'filter' }, 'Afficher'), filter),
    ),
    count,
    list,
  );

  let events: AdminEvent[] = [];

  async function load(): Promise<void> {
    try {
      events = await adminApi.events();
      render();
    } catch (e) {
      list.replaceChildren(notice('error', errorText(e)));
    }
  }

  function matches(ev: AdminEvent): boolean {
    const now = Date.now();
    const f = filter.value as Filter;
    if (f === 'visible' && ev.hidden_at) return false;
    if (f === 'hidden' && !ev.hidden_at) return false;
    if (f === 'live' && !(ev.status === 'published' && !ev.hidden_at
      && new Date(ev.starts_at).getTime() - 30 * 60_000 <= now && new Date(ev.ends_at).getTime() > now)) return false;
    const q = search.value.trim().toLocaleLowerCase('fr');
    return !q || [ev.title, ev.city, ev.organizer].some((s) => s.toLocaleLowerCase('fr').includes(q));
  }

  function render(): void {
    const shown = events.filter(matches);
    count.textContent = `${shown.length} manif${shown.length > 1 ? 's' : ''} sur ${events.length}`;
    list.replaceChildren(...(shown.length ? shown.map(card) : [h('p', { class: 'muted' }, 'Aucune manif ne correspond.')]));
  }

  search.addEventListener('input', render);
  filter.addEventListener('change', render);

  function card(ev: AdminEvent): HTMLElement {
    const c = cause(ev.cause);
    const ended = new Date(ev.ends_at).getTime() < Date.now();
    const slot = h('div', { class: 'reason-slot' });

    const statusChip = ev.status === 'cancelled'
      ? h('span', { class: 'chip status status-cancelled' }, 'Annulée')
      : h('span', { class: `chip status ${ended ? 'status-ended' : 'status-published'}` }, ended ? 'Terminée' : 'Publiée');

    const actions = ev.hidden_at
      ? h('button', {
        type: 'button', class: 'btn btn-soft',
        onclick: () => {
          if (confirm(`Rétablir « ${ev.title} » dans l'app ?`)) {
            void runAction(messages, 'Manifestation rétablie.', () => adminApi.unhide(ev.id), load);
          }
        },
      }, icon(ICONS.eye), 'Rétablir')
      : h('button', {
        type: 'button', class: 'btn btn-ghost',
        onclick: () => slot.replaceChildren(reasonForm({
          label: `Motif du masquage de « ${ev.title} »`,
          placeholder: 'Ex. : fausse manif, collectif usurpé, appel à la haine…',
          submit: 'Masquer la manif',
          onSubmit: (reason) => runAction(messages, 'Manifestation masquée.', () => adminApi.hide(ev.id, reason), load),
          onCancel: () => slot.replaceChildren(),
        })),
      }, icon(ICONS.eyeOff), 'Masquer');

    return h('article', { class: ev.hidden_at ? 'event-card is-hidden' : 'event-card', style: causeVars(ev.cause) },
      h('div', { class: 'event-icon', 'aria-hidden': 'true' }, icon(CAUSE_ICONS[c.icon] ?? CAUSE_ICONS.flag, 26)),
      h('div', { class: 'event-body' },
        h('div', { class: 'chips' },
          h('span', { class: 'chip chip-cause' }, c.label),
          statusChip,
          ev.hidden_at && h('span', { class: 'chip status-hidden' }, icon(ICONS.eyeOff, 14), 'Masquée'),
          ev.declared && h('span', { class: 'chip chip-outline' }, icon(ICONS.check, 14), 'Déclarée'),
          ev.purged_at && h('span', { class: 'chip chip-outline' }, 'Jetons purgés'),
        ),
        h('h2', {}, ev.title),
        h('p', { class: 'muted' }, `${formatWhen(ev.starts_at, ev.ends_at)} · ${ev.city} · par ${ev.organizer}`),
        h('p', { class: 'counts' },
          h('strong', {}, formatCount(ev.present)), ' présents vérifiés · ',
          h('strong', {}, formatCount(ev.supporters)), ' soutiens'),
        ev.hidden_at && h('p', { class: 'moderation-note' },
          h('strong', {}, `Masquée le ${formatDateTime(ev.hidden_at)} : `), ev.hidden_reason ?? ''),
        slot,
      ),
      h('div', { class: 'event-actions' }, actions),
    );
  }

  await load();
}
