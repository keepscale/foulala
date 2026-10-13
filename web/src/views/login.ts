import { h } from '../dom';
import { login, ApiError } from '../api';
import { logo, notice } from '../layout';

export function loginView(root: HTMLElement): void {
  const error = h('div', { 'aria-live': 'polite' });
  const email = h('input', { id: 'email', type: 'email', name: 'email', autocomplete: 'username', required: true });
  const password = h('input', {
    id: 'password', type: 'password', name: 'password', autocomplete: 'current-password', required: true,
  });
  const submit = h('button', { type: 'submit', class: 'btn btn-primary btn-block' }, 'Se connecter');

  const form = h('form', {
    class: 'login-card', novalidate: true,
    onsubmit: async (ev: Event) => {
      ev.preventDefault();
      error.replaceChildren();
      if (!email.value || !password.value) {
        error.append(notice('error', 'Renseignez votre e-mail et votre mot de passe.'));
        return;
      }
      submit.disabled = true;
      submit.textContent = 'Connexion…';
      try {
        await login(email.value, password.value);
        location.hash = '#/';
      } catch (e) {
        const msg = e instanceof ApiError ? e.message : 'Connexion impossible.';
        error.append(notice('error', msg));
        submit.disabled = false;
        submit.textContent = 'Se connecter';
        password.value = '';
        password.focus();
      }
    },
  },
    logo(40),
    h('h1', {}, 'Espace organisateur'),
    h('p', { class: 'muted' }, 'Déclarez vos manifestations, tracez le parcours, suivez le comptage.'),
    error,
    h('div', { class: 'field' }, h('label', { for: 'email' }, 'E-mail'), email),
    h('div', { class: 'field' }, h('label', { for: 'password' }, 'Mot de passe'), password),
    submit,
    h('p', { class: 'small muted' },
      'Les comptes sont créés sur invitation, pour éviter les fausses manifs. ',
      'Les participants, eux, n\'ont jamais de compte.'),
  );

  root.replaceChildren(h('main', { class: 'login-page' }, form));
  email.focus();
}
