import { h, icon, ICONS } from '../../dom';
import { adminApi, type AdminOrganizer } from '../../api';
import { formatCount, notice } from '../../layout';
import { adminPage, errorText, formatDateTime, reasonForm, runAction, secretBox } from '../../admin-layout';

/** Comptes des collectifs : invitation, suspension, nouveau mot de passe. */
export async function adminOrganizersView(root: HTMLElement): Promise<void> {
  const secret = h('div', {});
  const list = h('div', { class: 'org-list' }, h('p', { class: 'muted' }, 'Chargement…'));

  const name = h('input', { id: 'org-name', type: 'text', maxlength: 120, autocomplete: 'off', required: true });
  const email = h('input', { id: 'org-email', type: 'email', autocomplete: 'off', required: true });
  const invite = h('button', { type: 'submit', class: 'btn btn-primary' }, icon(ICONS.plus), 'Créer le compte');
  const inviteError = h('div', { 'aria-live': 'polite' });

  const inviteForm = h('form', {
    class: 'card', novalidate: true,
    onsubmit: async (ev: Event) => {
      ev.preventDefault();
      inviteError.replaceChildren();
      secret.replaceChildren();
      if (name.value.trim().length < 2 || !email.value.includes('@')) {
        inviteError.append(notice('error', 'Indiquez le nom du collectif et une adresse e-mail valide.'));
        return;
      }
      invite.disabled = true;
      try {
        const r = await adminApi.invite(name.value.trim(), email.value.trim());
        secret.replaceChildren(secretBox('Compte créé. Mot de passe provisoire :',
          `${name.value.trim()} · ${email.value.trim().toLowerCase()}`, r.password));
        name.value = '';
        email.value = '';
        await load();
      } catch (e) {
        inviteError.append(notice('error', errorText(e)));
      } finally {
        invite.disabled = false;
      }
    },
  },
    h('h2', { class: 'section-title' }, 'Inviter un collectif'),
    h('p', { class: 'small muted' },
      'Pas d\'inscription libre : vérifiez d\'abord que le collectif existe et que l\'adresse est bien la sienne.'),
    inviteError,
    h('div', { class: 'row' },
      h('div', { class: 'field' }, h('label', { for: 'org-name' }, 'Nom du collectif'), name),
      h('div', { class: 'field' }, h('label', { for: 'org-email' }, 'E-mail de contact'), email),
    ),
    h('div', { class: 'actions' }, invite),
  );

  const messages = adminPage(root, 'collectifs', 'Collectifs',
    'Les seuls comptes de Foulala. Suspendre un compte bloque aussitôt sa connexion ; ses manifs restent en ligne tant qu\'elles ne sont pas masquées.',
    inviteForm, secret, list);

  async function load(): Promise<void> {
    try {
      const rows = await adminApi.organizers();
      list.replaceChildren(...(rows.length ? rows.map(row) : [h('p', { class: 'muted' }, 'Aucun compte.')]));
    } catch (e) {
      list.replaceChildren(notice('error', errorText(e)));
    }
  }

  function row(o: AdminOrganizer): HTMLElement {
    const slot = h('div', { class: 'reason-slot' });
    const suspended = o.suspended_at !== null;

    const actions: HTMLElement[] = [
      h('button', {
        type: 'button', class: 'btn btn-soft btn-sm',
        onclick: async () => {
          if (!confirm(`Créer un nouveau mot de passe provisoire pour « ${o.name} » ?\n\nL'ancien ne marchera plus.`)) return;
          messages.replaceChildren();
          secret.replaceChildren();
          try {
            const r = await adminApi.resetPassword(o.id);
            secret.replaceChildren(secretBox('Nouveau mot de passe provisoire :', `${o.name} · ${o.email}`, r.password));
            secret.scrollIntoView({ behavior: 'smooth', block: 'center' });
          } catch (e) {
            messages.append(notice('error', errorText(e)));
          }
        },
      }, icon(ICONS.key), 'Nouveau mot de passe'),
    ];
    if (suspended) {
      actions.push(h('button', {
        type: 'button', class: 'btn btn-soft btn-sm',
        onclick: () => {
          if (confirm(`Réactiver le compte de « ${o.name} » ?`)) {
            void runAction(messages, 'Compte réactivé.', () => adminApi.reactivate(o.id), load);
          }
        },
      }, icon(ICONS.play), 'Réactiver'));
    } else {
      actions.push(h('button', {
        type: 'button', class: 'btn btn-ghost btn-sm',
        onclick: () => slot.replaceChildren(reasonForm({
          label: `Motif de la suspension de « ${o.name} »`,
          placeholder: 'Ex. : usurpation d\'un collectif, fausses manifs répétées…',
          submit: 'Suspendre le compte',
          onSubmit: (reason) => runAction(messages, 'Compte suspendu.', () => adminApi.suspend(o.id, reason), load),
          onCancel: () => slot.replaceChildren(),
        })),
      }, icon(ICONS.pause), 'Suspendre'));
    }

    return h('article', { class: suspended ? 'org-card is-suspended' : 'org-card' },
      h('div', { class: 'org-body' },
        h('div', { class: 'chips' },
          suspended
            ? h('span', { class: 'chip status-cancelled' }, 'Suspendu')
            : h('span', { class: 'chip status-published' }, 'Actif'),
        ),
        h('h2', {}, o.name),
        h('p', { class: 'muted' }, o.email),
        h('p', { class: 'small muted' },
          `Compte créé le ${formatDateTime(o.created_at)} · ${formatCount(o.events)} manif(s) publiée(s) · ${formatCount(o.drafts)} brouillon(s)`),
        suspended && h('p', { class: 'moderation-note' },
          h('strong', {}, `Suspendu le ${formatDateTime(o.suspended_at)} : `), o.suspended_reason ?? ''),
        slot,
      ),
      h('div', { class: 'event-actions' }, actions),
    );
  }

  await load();
}
