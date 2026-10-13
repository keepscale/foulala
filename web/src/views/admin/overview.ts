import { h, icon, ICONS } from '../../dom';
import { adminApi, type AdminOverview, type GroupStats } from '../../api';
import { cause } from '../../theme';
import { formatCount, notice } from '../../layout';
import { adminPage, errorText, formatDateTime } from '../../admin-layout';

/** Pilotage : chiffres globaux (agrégés) et santé du système. */
export async function adminOverviewView(root: HTMLElement): Promise<void> {
  const body = h('div', { class: 'admin-stack' }, h('p', { class: 'muted' }, 'Chargement…'));
  const refresh = h('button', { type: 'button', class: 'btn btn-soft' }, icon(ICONS.refresh), 'Actualiser');
  const messages = adminPage(root, 'pilotage', 'Pilotage',
    'Totaux additionnés manif par manif : jamais un jeton, une présence ni un soutien isolé.',
    h('div', { class: 'actions' }, refresh), body);

  async function load(): Promise<void> {
    messages.replaceChildren();
    try {
      render(await adminApi.overview());
    } catch (e) {
      body.replaceChildren(notice('error', errorText(e)));
    }
  }
  refresh.addEventListener('click', () => void load());

  function render(o: AdminOverview): void {
    body.replaceChildren(
      h('section', { class: 'tiles', 'aria-label': 'Chiffres clés' },
        tile(formatCount(o.totals.present), 'présents vérifiés, toutes manifs', true),
        tile(formatCount(o.totals.supporters), 'soutiens'),
        tile(formatCount(o.events.live), 'manifs en cours'),
        tile(formatCount(o.events.upcoming), 'à venir'),
        tile(formatCount(o.events.ended), 'terminées'),
        tile(formatCount(o.organizers.active), 'collectifs actifs'),
      ),
      health(o),
      h('div', { class: 'columns' },
        h('section', { class: 'card form-col' },
          h('h2', { class: 'section-title' }, 'Manifestations par état'),
          stateList([
            ['En cours', o.events.live],
            ['À venir', o.events.upcoming],
            ['Terminées', o.events.ended],
            ['Annulées', o.events.cancelled],
            ['Masquées par la modération', o.events.hidden],
            ['Brouillons (non publics)', o.events.draft],
            ['Collectifs suspendus', o.organizers.suspended],
          ]),
        ),
        groupTable('Par cause', 'Cause', o.by_cause, (g) => g.cause ? cause(g.cause).label : '—', 'card map-col'),
      ),
      groupTable('Par ville', 'Ville', o.by_city, (g) => g.city ?? '—', 'card'),
    );
  }

  await load();
}

function tile(value: string, label: string, primary = false): HTMLElement {
  return h('div', { class: primary ? 'tile tile-primary' : 'tile' },
    h('span', { class: 'tile-value' }, value),
    h('span', { class: 'tile-label' }, label),
  );
}

function stateList(rows: [string, number][]): HTMLElement {
  return h('dl', { class: 'state-list' },
    rows.map(([label, n]) => h('div', {}, h('dt', {}, label), h('dd', {}, formatCount(n)))),
  );
}

function groupTable(
  title: string, column: string, rows: GroupStats[], name: (g: GroupStats) => string, cls: string,
): HTMLElement {
  return h('section', { class: cls },
    h('h2', { class: 'section-title' }, title),
    rows.length === 0
      ? h('p', { class: 'muted' }, 'Pas encore de manif publiée.')
      : h('div', { class: 'table-wrap' },
        h('table', { class: 'data' },
          h('thead', {}, h('tr', {},
            h('th', { scope: 'col' }, column),
            h('th', { scope: 'col', class: 'num' }, 'Manifs'),
            h('th', { scope: 'col', class: 'num' }, 'Présents'),
            h('th', { scope: 'col', class: 'num' }, 'Soutiens'),
          )),
          h('tbody', {}, rows.map((g) => h('tr', {},
            h('th', { scope: 'row' }, name(g)),
            h('td', { class: 'num' }, formatCount(g.events)),
            h('td', { class: 'num' }, formatCount(g.present)),
            h('td', { class: 'num' }, formatCount(g.supporters)),
          ))),
        ),
      ),
  );
}

/** Santé : chaque ligne dit en toutes lettres si c'est normal (jamais la couleur seule). */
function health(o: AdminOverview): HTMLElement {
  const hl = o.health;
  const cron = hl.last_cron;
  const cronOk = cron === null ? null : cron.status === 'succeeded';
  const rows: { ok: boolean | null; label: string; value: string; help?: string }[] = [
    {
      ok: hl.overdue_purges === 0,
      label: 'Purges en retard',
      value: hl.overdue_purges === 0 ? 'Aucune' : `${formatCount(hl.overdue_purges)} manif(s)`,
      help: 'Les jetons doivent disparaître 24 h après la fin de chaque manif.',
    },
    {
      ok: cronOk,
      label: 'Dernière purge automatique',
      value: cron === null
        ? 'pg_cron absent (base de test ?)'
        : `${cron.status === 'succeeded' ? 'Réussie' : `Échec : ${cron.message ?? cron.status}`} · ${formatDateTime(cron.at)}`,
    },
    { ok: null, label: 'Prochaine purge prévue', value: formatDateTime(hl.next_purge) },
    {
      ok: null,
      label: 'Jetons encore en base',
      value: formatCount(hl.tokens_stored),
      help: 'Un nombre seulement : les jetons eux-mêmes ne sont jamais lisibles ici.',
    },
    { ok: null, label: 'Taille de la base', value: hl.database_size },
  ];

  return h('section', { class: 'card' },
    h('div', { class: 'map-head' },
      h('h2', { class: 'section-title' }, 'Santé du système'),
      h('span', { class: 'small muted' }, `Vérifié ${formatDateTime(hl.checked_at)}`),
    ),
    h('ul', { class: 'health' },
      rows.map((r) => h('li', { class: r.ok === null ? 'health-row' : r.ok ? 'health-row ok' : 'health-row warn' },
        h('span', { class: 'health-mark', 'aria-hidden': 'true' }, r.ok === null ? '·' : r.ok ? '✓' : '!'),
        h('span', { class: 'health-label' }, r.label,
          r.help && h('span', { class: 'small muted health-help' }, r.help)),
        h('strong', { class: 'health-value' }, r.value, r.ok === false ? ' — à vérifier' : ''),
      )),
    ),
  );
}
