import { h, icon, ICONS } from '../dom';
import { api, ApiError } from '../api';
import { header, notice } from '../layout';

/** Changement de mot de passe d'un collectif (après une invitation ou un nouveau mot de passe provisoire). */
export function passwordView(root: HTMLElement): void {
  const messages = h('div', { 'aria-live': 'polite' });
  const current = h('input', { id: 'current', type: 'password', autocomplete: 'current-password', required: true });
  const next = h('input', {
    id: 'next', type: 'password', autocomplete: 'new-password', minlength: 12, required: true,
    'aria-describedby': 'next-help',
  });
  const confirmField = h('input', { id: 'confirm', type: 'password', autocomplete: 'new-password', required: true });
  const submit = h('button', { type: 'submit', class: 'btn btn-primary' }, 'Changer le mot de passe');

  const form = h('form', {
    class: 'card narrow', novalidate: true,
    onsubmit: async (ev: Event) => {
      ev.preventDefault();
      messages.replaceChildren();
      if (next.value.length < 12) {
        messages.append(notice('error', 'Le nouveau mot de passe doit faire 12 caractères au moins.'));
        return;
      }
      if (next.value !== confirmField.value) {
        messages.append(notice('error', 'Les deux nouveaux mots de passe ne sont pas identiques.'));
        return;
      }
      submit.disabled = true;
      try {
        await api.changePassword(current.value, next.value);
        form.reset();
        messages.append(notice('info', 'Mot de passe changé.'));
      } catch (e) {
        messages.append(notice('error', e instanceof ApiError ? e.message : 'Changement impossible.'));
      } finally {
        submit.disabled = false;
      }
    },
  },
    h('div', { class: 'field' }, h('label', { for: 'current' }, 'Mot de passe actuel'), current),
    h('div', { class: 'field' },
      h('label', { for: 'next' }, 'Nouveau mot de passe'),
      next,
      h('p', { id: 'next-help', class: 'small muted' }, '12 caractères au moins. Une phrase de quelques mots est plus facile à retenir.'),
    ),
    h('div', { class: 'field' }, h('label', { for: 'confirm' }, 'Nouveau mot de passe, encore une fois'), confirmField),
    h('div', { class: 'actions' }, submit),
  );

  root.replaceChildren(
    header(),
    h('main', { class: 'container' },
      h('a', { href: '#/', class: 'back-link' }, icon(ICONS.back), 'Mes manifestations'),
      h('div', { class: 'page-head' },
        h('div', {}, h('h1', {}, 'Mot de passe'),
          h('p', { class: 'muted' }, 'Si vous avez reçu un mot de passe provisoire, remplacez-le ici.')),
      ),
      messages,
      form,
    ),
  );
  current.focus();
}
