import { h } from '../../dom';
import { adminApi, type AdminLogEntry } from '../../api';
import { notice } from '../../layout';
import { adminPage, errorText, formatDateTime } from '../../admin-layout';

/** Journal : qui a fait quoi, sur quel compte ou quelle manif, et pourquoi. */
export async function adminJournalView(root: HTMLElement): Promise<void> {
  const body = h('div', {}, h('p', { class: 'muted' }, 'Chargement…'));
  adminPage(root, 'journal', 'Journal',
    'Les 200 dernières actions de l\'administration. Il ne contient que des comptes et des manifs, jamais de participant.',
    h('section', { class: 'card' }, body));

  try {
    const rows = await adminApi.log();
    body.replaceChildren(rows.length ? table(rows) : h('p', { class: 'muted' }, 'Aucune action pour l\'instant.'));
  } catch (e) {
    body.replaceChildren(notice('error', errorText(e)));
  }
}

function table(rows: AdminLogEntry[]): HTMLElement {
  return h('div', { class: 'table-wrap' },
    h('table', { class: 'data' },
      h('thead', {}, h('tr', {},
        h('th', { scope: 'col' }, 'Quand'),
        h('th', { scope: 'col' }, 'Qui'),
        h('th', { scope: 'col' }, 'Action'),
        h('th', { scope: 'col' }, 'Sur'),
        h('th', { scope: 'col' }, 'Motif'),
      )),
      h('tbody', {}, rows.map((r) => h('tr', {},
        h('td', { class: 'nowrap' }, formatDateTime(r.at)),
        h('td', {}, r.admin),
        h('td', {}, h('span', { class: 'chip chip-outline' }, r.action)),
        h('td', {}, `${r.target_kind === 'event' ? 'Manif' : 'Collectif'} · ${r.target ?? 'supprimé'}`),
        h('td', {}, r.reason ?? '—'),
      ))),
    ),
  );
}
