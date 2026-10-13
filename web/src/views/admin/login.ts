import { h, icon, ICONS } from '../../dom';
import { adminLogin, ApiError } from '../../api';
import { logo, notice } from '../../layout';

/** Connexion de l'administration : mot de passe + code à usage unique (appli d'authentification). */
export function adminLoginView(root: HTMLElement): void {
  const error = h('div', { 'aria-live': 'polite' });
  const email = h('input', { id: 'email', type: 'email', name: 'email', autocomplete: 'username', required: true });
  const password = h('input', {
    id: 'password', type: 'password', name: 'password', autocomplete: 'current-password', required: true,
  });
  const code = h('input', {
    id: 'code', type: 'text', name: 'code', inputmode: 'numeric', autocomplete: 'one-time-code',
    pattern: '[0-9]{6}', maxlength: 6, required: true, 'aria-describedby': 'code-help',
  });
  const submit = h('button', { type: 'submit', class: 'btn btn-primary btn-block' }, 'Se connecter');

  const form = h('form', {
    class: 'login-card login-admin', novalidate: true,
    onsubmit: async (ev: Event) => {
      ev.preventDefault();
      error.replaceChildren();
      const otp = code.value.replace(/\s/g, '');
      if (!email.value || !password.value || !/^\d{6}$/.test(otp)) {
        error.append(notice('error', 'Renseignez l\'e-mail, le mot de passe et le code à 6 chiffres.'));
        return;
      }
      submit.disabled = true;
      submit.textContent = 'Connexion…';
      try {
        await adminLogin(email.value, password.value, otp);
        location.hash = '#/admin';
      } catch (e) {
        error.append(notice('error', e instanceof ApiError ? e.message : 'Connexion impossible.'));
        submit.disabled = false;
        submit.textContent = 'Se connecter';
        code.value = '';
        code.focus();
      }
    },
  },
    logo(40),
    h('p', { class: 'admin-badge' }, icon(ICONS.shield, 16), 'Administration'),
    h('h1', {}, 'Pilotage de Foulala'),
    h('p', { class: 'muted' }, 'Modération, comptes des collectifs, santé du serveur. Aucune donnée de participant n\'est accessible ici.'),
    error,
    h('div', { class: 'field' }, h('label', { for: 'email' }, 'E-mail'), email),
    h('div', { class: 'field' }, h('label', { for: 'password' }, 'Mot de passe'), password),
    h('div', { class: 'field' },
      h('label', { for: 'code' }, 'Code de l\'appli d\'authentification'),
      code,
      h('p', { id: 'code-help', class: 'small muted' }, '6 chiffres, renouvelés toutes les 30 secondes. Un code ne sert qu\'une fois.'),
    ),
    submit,
    h('p', { class: 'small muted' }, h('a', { href: '#/connexion' }, 'Espace organisateur')),
  );

  root.replaceChildren(h('main', { class: 'login-page' }, form));
  email.focus();
}
