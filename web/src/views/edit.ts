import { h, icon, ICONS } from '../dom';
import { api, ApiError, type CauseId, type EventInput, type MyEvent } from '../api';
import { CAUSES, cause, causeVars, CAUSE_ICONS } from '../theme';
import { header, notice } from '../layout';
import { createRouteEditor, type RouteEditor } from '../route-editor';

const MAX_DEMANDS = 10;

export async function editView(root: HTMLElement, id: string | null): Promise<() => void> {
  let existing: MyEvent | null = null;
  if (id) {
    try {
      existing = await api.myEvent(id);
    } catch (e) {
      root.replaceChildren(header(), h('main', { class: 'container' },
        notice('error', e instanceof ApiError ? e.message : 'Manifestation introuvable.'),
        h('a', { href: '#/', class: 'btn btn-soft' }, icon(ICONS.back), 'Mes manifestations')));
      return () => {};
    }
  }
  const readonly = existing !== null && existing.status !== 'draft';

  // État du formulaire
  let selectedCause: CauseId = existing?.cause ?? 'autre';
  let demands: string[] = existing?.demands.length ? [...existing.demands] : [''];

  const messages = h('div', { 'aria-live': 'polite' });
  const page = h('main', { class: 'container', style: causeVars(selectedCause) });

  // 1. Cause --------------------------------------------------------
  const causeButtons = CAUSES.map((c) => {
    const b = h('button', {
      type: 'button', class: 'cause-chip', style: causeVars(c.id), 'aria-pressed': String(c.id === selectedCause),
      disabled: readonly,
      onclick: () => {
        selectedCause = c.id;
        causeButtons.forEach((x) => x.setAttribute('aria-pressed', String(x === b)));
        page.setAttribute('style', causeVars(c.id));
        editor?.setColors(c.primary, c.deep);
      },
    }, icon(CAUSE_ICONS[c.icon] ?? CAUSE_ICONS.flag, 20), c.label);
    return b;
  });

  // 2. Informations ------------------------------------------------
  const title = input('titre', 'text', existing?.title ?? '', { maxlength: 120, required: true });
  const city = input('ville', 'text', existing?.city ?? '', { maxlength: 80, required: true, autocomplete: 'address-level2' });
  const startsAt = input('debut', 'datetime-local', toLocalInput(existing?.starts_at), { required: true });
  const endsAt = input('fin', 'datetime-local', toLocalInput(existing?.ends_at), { required: true });
  const description = h('textarea', { id: 'description', rows: 4, maxlength: 2000, disabled: readonly });
  description.value = existing?.description ?? '';
  const declared = h('input', { id: 'declaree', type: 'checkbox', disabled: readonly });
  declared.checked = existing?.declared ?? false;

  // 3. Revendications ----------------------------------------------
  const demandList = h('div', { class: 'demands' });
  function renderDemands(): void {
    demandList.replaceChildren(...demands.map((value, i) => {
      const field = h('input', {
        type: 'text', id: `rev${i}`, maxlength: 200, value, disabled: readonly,
        oninput: (e: Event) => { demands[i] = (e.target as HTMLInputElement).value; },
      });
      return h('div', { class: 'demand-row' },
        h('span', { class: 'demand-num', 'aria-hidden': 'true' }, String(i + 1)),
        h('label', { for: `rev${i}`, class: 'sr-only' }, `Revendication ${i + 1}`),
        field,
        !readonly && h('button', {
          type: 'button', class: 'icon-btn', 'aria-label': `Supprimer la revendication ${i + 1}`,
          onclick: () => {
            demands.splice(i, 1);
            if (!demands.length) demands.push('');
            renderDemands();
          },
        }, icon(ICONS.close)),
      );
    }));
    if (!readonly && demands.length < MAX_DEMANDS) {
      demandList.append(h('button', {
        type: 'button', class: 'btn btn-dashed',
        onclick: () => {
          demands.push('');
          renderDemands();
          (demandList.querySelector(`#rev${demands.length - 1}`) as HTMLInputElement | null)?.focus();
        },
      }, icon(ICONS.plus), 'Ajouter une revendication'));
    }
  }
  renderDemands();

  // 5. Parcours ----------------------------------------------------
  const bufferValue = h('span', { class: 'pill' }, `${existing?.buffer_m ?? 100} m`);
  const buffer = h('input', {
    id: 'largeur', type: 'range', min: 20, max: 500, step: 10, value: existing?.buffer_m ?? 100, disabled: readonly,
    oninput: () => {
      bufferValue.textContent = `${buffer.value} m`;
      editor?.setBuffer(Number(buffer.value));
    },
  });
  const stats = h('span', { class: 'pill' });
  const mapEl = h('div', { class: 'map', role: 'application', 'aria-label': 'Carte : cliquez pour ajouter un point du parcours, glissez un point pour le déplacer' });

  // Actions ---------------------------------------------------------
  const saveBtn = h('button', { type: 'button', class: 'btn btn-outline', onclick: () => void save(false) }, 'Enregistrer le brouillon');
  const publishBtn = h('button', { type: 'button', class: 'btn btn-primary', onclick: () => void save(true) }, 'Publier');

  const status = existing?.status ?? 'draft';
  page.append(
    h('a', { href: '#/', class: 'back-link' }, icon(ICONS.back), 'Mes manifestations'),
    h('div', { class: 'page-head' },
      h('div', {},
        h('div', { class: 'title-row' },
          h('h1', {}, existing ? (readonly ? existing.title : 'Modifier la manifestation') : 'Nouvelle manifestation'),
          h('span', { class: `chip status status-${status}` }, { draft: 'Brouillon', published: 'Publiée', cancelled: 'Annulée' }[status]),
        ),
        h('p', { class: 'muted' }, readonly
          ? 'Une manif publiée ne se modifie plus : son parcours et ses horaires fondent le comptage.'
          : 'Le public verra le parcours, les horaires et les revendications. Une présence n\'est comptée que dans la zone, pendant le créneau.'),
      ),
      !readonly && h('div', { class: 'actions' }, saveBtn, publishBtn),
    ),
    messages,
    h('section', { class: 'card' },
      h('h2', { class: 'section-title' }, '1 · Cause'),
      h('p', { class: 'muted' }, 'Elle donne sa couleur, son icône et son motif à la manif dans l\'app.'),
      h('div', { class: 'cause-picker', role: 'group', 'aria-label': 'Cause de la manifestation' }, causeButtons),
    ),
    h('div', { class: 'columns' },
      h('div', { class: 'card form-col' },
        h('h2', { class: 'section-title' }, '2 · Informations'),
        field('titre', 'Titre', title),
        h('div', { class: 'city-row' }, field('ville', 'Ville', city),
          !readonly && h('button', {
            type: 'button', class: 'btn btn-soft', title: 'Centrer la carte sur la ville (recherche OpenStreetMap)',
            onclick: () => void centerOnCity(),
          }, 'Centrer la carte')),
        h('div', { class: 'row' }, field('debut', 'Début', startsAt), field('fin', 'Fin', endsAt)),
        field('description', 'Description', description),
        h('h2', { class: 'section-title' }, '3 · Revendications'),
        demandList,
        h('h2', { class: 'section-title' }, '4 · Déclaration'),
        h('div', { class: 'declare' },
          declared,
          h('div', {},
            h('label', { for: 'declaree' }, 'J\'ai déclaré cette manifestation en mairie ou en préfecture'),
            h('p', { class: 'small muted' }, 'Obligatoire en France, de 3 à 15 jours francs avant la date. Foulala ne fait pas la déclaration à votre place.'),
          ),
        ),
      ),
      h('div', { class: 'card map-col' },
        h('div', { class: 'map-head' }, h('h2', { class: 'section-title' }, '5 · Parcours et zone de présence'), stats),
        !readonly && h('div', { class: 'toolbar' },
          h('span', { class: 'small muted' }, 'Cliquez sur la carte pour ajouter un point, glissez un point pour le déplacer.'),
          h('button', { type: 'button', class: 'btn btn-soft btn-sm', onclick: () => editor?.undo() }, icon(ICONS.undo), 'Annuler le dernier point'),
          h('button', { type: 'button', class: 'btn btn-soft btn-sm', onclick: () => editor?.clear() }, icon(ICONS.trash), 'Effacer'),
        ),
        mapEl,
        h('div', { class: 'stripe', 'aria-hidden': 'true' }),
        h('div', { class: 'field' },
          h('div', { class: 'label-row' }, h('label', { for: 'largeur' }, 'Largeur de la zone, de chaque côté du parcours'), bufferValue),
          buffer,
        ),
        h('p', { class: 'small muted' }, 'Les participants ne peuvent dire « J\'y suis ! » que dans cette zone, de 30 minutes avant le départ jusqu\'à la fin.'),
      ),
    ),
  );

  root.replaceChildren(header(), page);

  const c0 = cause(selectedCause);
  const editor: RouteEditor = createRouteEditor(
    mapEl, existing?.route ?? null, Number(buffer.value), { primary: c0.primary, deep: c0.deep }, updateStats, readonly,
  );
  updateStats();

  function updateStats(): void {
    const m = editor ? editor.lengthMeters() : 0;
    const segments = Math.max(1, Math.min(100, Math.ceil(m / 200)));
    stats.textContent = m < 1 ? 'Aucun point' : `${(m / 1000).toLocaleString('fr-FR', { maximumFractionDigits: 1 })} km · ${segments} tronçons`;
  }

  // Recherche de la ville sur Nominatim (OpenStreetMap), seulement sur demande.
  // Seul le nom de la ville part, depuis le navigateur de l'organisateur.
  async function centerOnCity(): Promise<void> {
    messages.replaceChildren();
    const q = city.value.trim();
    if (!q) {
      messages.append(notice('error', 'Indiquez d\'abord la ville.'));
      return;
    }
    try {
      const url = `https://nominatim.openstreetmap.org/search?format=json&limit=1&accept-language=fr&q=${encodeURIComponent(q)}`;
      const res = await fetch(url, { credentials: 'omit' });
      const found = (await res.json()) as { lat: string; lon: string }[];
      if (!found.length) {
        messages.append(notice('error', `Ville introuvable : ${q}`));
        return;
      }
      editor.centerOn(Number(found[0].lat), Number(found[0].lon));
    } catch {
      messages.append(notice('error', 'Recherche de la ville impossible. Déplacez la carte à la main.'));
    }
  }

  function collect(): EventInput | string {
    const route = editor.getRoute();
    if (title.value.trim().length < 3) return 'Le titre doit faire au moins 3 caractères.';
    if (!city.value.trim()) return 'La ville est obligatoire.';
    if (!startsAt.value || !endsAt.value) return 'Indiquez le début et la fin.';
    const s = new Date(startsAt.value);
    const e = new Date(endsAt.value);
    if (e <= s) return 'La fin doit être après le début.';
    if (!route) return 'Tracez le parcours : au moins deux points sur la carte.';
    return {
      title: title.value.trim(),
      cause: selectedCause,
      city: city.value.trim(),
      starts_at: s.toISOString(),
      ends_at: e.toISOString(),
      route,
      buffer_m: Number(buffer.value),
      description: description.value.trim() || null,
      demands: demands.map((d) => d.trim()).filter(Boolean),
      declared: declared.checked,
    };
  }

  async function save(publish: boolean): Promise<void> {
    messages.replaceChildren();
    const data = collect();
    if (typeof data === 'string') {
      messages.append(notice('error', data));
      return;
    }
    if (publish && !confirm('Publier cette manifestation ?\n\nElle sera visible dans l\'app. Le parcours et les horaires ne pourront plus être modifiés.')) {
      return;
    }
    saveBtn.disabled = publishBtn.disabled = true;
    try {
      let eventId = existing?.id ?? null;
      if (eventId) await api.update(eventId, data);
      else eventId = await api.create(data);
      if (publish) await api.publish(eventId);
      location.hash = '#/';
    } catch (e) {
      messages.append(notice('error', e instanceof ApiError ? e.message : 'Enregistrement impossible.'));
      saveBtn.disabled = publishBtn.disabled = false;
    }
  }

  function input(id: string, type: string, value: string, extra: Record<string, string | number | boolean> = {}): HTMLInputElement {
    return h('input', { id, type, value, disabled: readonly, ...extra });
  }

  return () => editor.destroy();
}

function field(id: string, label: string, control: HTMLElement): HTMLElement {
  return h('div', { class: 'field' }, h('label', { for: id }, label), control);
}

/** ISO → valeur d'un <input type="datetime-local"> dans le fuseau du navigateur. */
function toLocalInput(iso: string | undefined): string {
  if (!iso) return '';
  const d = new Date(iso);
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
}
