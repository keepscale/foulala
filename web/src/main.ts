import './style.css';
import { session } from './api';
import { logoUrl } from './layout';
import { loginView } from './views/login';
import { listView } from './views/list';
import { editView } from './views/edit';

const root = document.getElementById('app')!;
let cleanup: () => void = () => {};

// Favicon : le logo de design/
const fav = document.createElement('link');
fav.rel = 'icon';
fav.type = 'image/svg+xml';
fav.href = logoUrl;
document.head.appendChild(fav);

// Routes (hash, pour marcher sur GitHub Pages sans configuration) :
//   #/connexion · #/ · #/nouvelle · #/manif/<id>
async function route(): Promise<void> {
  cleanup();
  cleanup = () => {};
  window.scrollTo(0, 0);
  const hash = location.hash.replace(/^#/, '') || '/';

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
  const m = hash.match(/^\/manif\/([0-9a-f-]{36})$/);
  if (m) {
    cleanup = await editView(root, m[1]);
    return;
  }
  location.hash = '#/';
}

window.addEventListener('hashchange', () => void route());
void route();
