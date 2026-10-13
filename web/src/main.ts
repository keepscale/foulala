import './style.css';
import { session } from './api';
import { logoUrl } from './layout';
import { loginView } from './views/login';
import { listView } from './views/list';
import { editView } from './views/edit';
import { passwordView } from './views/password';
import { adminLoginView } from './views/admin/login';
import { adminOverviewView } from './views/admin/overview';
import { adminEventsView } from './views/admin/events';
import { adminOrganizersView } from './views/admin/organizers';
import { adminJournalView } from './views/admin/journal';

const root = document.getElementById('app')!;
let cleanup: () => void = () => {};

// Favicon : le logo de design/
const fav = document.createElement('link');
fav.rel = 'icon';
fav.type = 'image/svg+xml';
fav.href = logoUrl;
document.head.appendChild(fav);

// Routes (hash, pour marcher sur GitHub Pages sans configuration) :
//   organisateur   : #/connexion · #/ · #/nouvelle · #/manif/<id> · #/mot-de-passe
//   administration : #/admin/connexion · #/admin · #/admin/manifs · #/admin/collectifs · #/admin/journal
async function route(): Promise<void> {
  cleanup();
  cleanup = () => {};
  window.scrollTo(0, 0);
  const hash = location.hash.replace(/^#/, '') || '/';

  if (hash.startsWith('/admin')) {
    await adminRoute(hash);
    return;
  }

  if (!session()) {
    if (hash !== '/connexion') {
      location.hash = '#/connexion';
      return;
    }
    loginView(root);
    return;
  }
  if (hash === '/connexion' || hash === '/') {
    if (hash === '/connexion') location.hash = '#/';
    else await listView(root);
    return;
  }
  if (hash === '/nouvelle') {
    cleanup = await editView(root, null);
    return;
  }
  if (hash === '/mot-de-passe') {
    passwordView(root);
    return;
  }
  const m = hash.match(/^\/manif\/([0-9a-f-]{36})$/);
  if (m) {
    cleanup = await editView(root, m[1]);
    return;
  }
  location.hash = '#/';
}

// Session d'administration séparée de celle des organisateurs
async function adminRoute(hash: string): Promise<void> {
  document.title = 'Foulala · Administration';
  if (!session('admin')) {
    if (hash !== '/admin/connexion') {
      location.hash = '#/admin/connexion';
      return;
    }
    adminLoginView(root);
    return;
  }
  switch (hash) {
    case '/admin/connexion':
      location.hash = '#/admin';
      return;
    case '/admin':
      await adminOverviewView(root);
      return;
    case '/admin/manifs':
      await adminEventsView(root);
      return;
    case '/admin/collectifs':
      await adminOrganizersView(root);
      return;
    case '/admin/journal':
      await adminJournalView(root);
      return;
    default:
      location.hash = '#/admin';
  }
}

window.addEventListener('hashchange', () => {
  if (!location.hash.startsWith('#/admin')) document.title = 'Foulala · Espace organisateur';
  void route();
});
void route();
