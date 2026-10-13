// Client de l'API PostgREST. Les jetons ne vivent que le temps de l'onglet
// (sessionStorage) et expirent côté serveur : 8 h pour un organisateur, 1 h pour
// l'administration. Les deux sessions sont séparées.

export const API_URL = (import.meta.env.VITE_API_URL as string | undefined)?.replace(/\/$/, '')
  ?? 'http://localhost:3000';

// Supabase (tests seulement) : clé publique, la même pour tous les navigateurs.
// Vide avec le serveur Foulala (server/), qui n'en a pas besoin.
const API_KEY = (import.meta.env.VITE_API_KEY as string | undefined) ?? '';

/** Base de test Supabase : elle journalise les adresses IP, jamais pour une vraie manif. */
export const IS_TEST_BACKEND = API_URL.includes('.supabase.co');

export type CauseId = 'climat' | 'fiertes' | 'paix' | 'social' | 'sante' | 'education' | 'autre';
export type Status = 'draft' | 'published' | 'cancelled';

export interface LineString {
  type: 'LineString';
  coordinates: [number, number][]; // [longitude, latitude]
}

export interface MyEvent {
  id: string;
  title: string;
  cause: CauseId;
  description: string | null;
  demands: string[];
  city: string;
  starts_at: string;
  ends_at: string;
  declared: boolean;
  status: Status;
  buffer_m: number;
  segment_count: number;
  purged_at: string | null;
  created_at: string;
  route: LineString;
  present: number | null;
  supporters: number | null;
  /** Masquée par la modération de Foulala, avec le motif */
  hidden_at: string | null;
  hidden_reason: string | null;
}

export interface EventInput {
  title: string;
  cause: CauseId;
  city: string;
  starts_at: string;
  ends_at: string;
  route: LineString;
  buffer_m: number;
  description: string | null;
  demands: string[];
  declared: boolean;
}

interface Session {
  token: string;
  expires_at: string;
  name: string;
}

/** Qui appelle : un organisateur ou l'administration (null : connexion, sans jeton). */
export type Who = 'organizer' | 'admin';

const SESSION_KEYS: Record<Who, string> = {
  organizer: 'foulala.organisateur',
  admin: 'foulala.admin',
};

const LOGIN_ROUTES: Record<Who, string> = {
  organizer: '#/connexion',
  admin: '#/admin/connexion',
};

export class ApiError extends Error {
  constructor(message: string, readonly status: number) {
    super(message);
  }
}

// Repli si le navigateur refuse sessionStorage (navigation privée stricte)
const memorySessions: Record<Who, Session | null> = { organizer: null, admin: null };

export function session(who: Who = 'organizer'): Session | null {
  try {
    const raw = sessionStorage.getItem(SESSION_KEYS[who]);
    if (!raw) return null;
    const s = JSON.parse(raw) as Session;
    if (new Date(s.expires_at).getTime() <= Date.now()) {
      sessionStorage.removeItem(SESSION_KEYS[who]);
      return null;
    }
    return s;
  } catch {
    return memorySessions[who];
  }
}

function saveSession(s: Session | null, who: Who): void {
  memorySessions[who] = s;
  try {
    if (s) sessionStorage.setItem(SESSION_KEYS[who], JSON.stringify(s));
    else sessionStorage.removeItem(SESSION_KEYS[who]);
  } catch {
    /* mémoire seulement */
  }
}

export function logout(who: Who = 'organizer'): void {
  saveSession(null, who);
}

async function call<T>(path: string, init: RequestInit = {}, who: Who | null = 'organizer'): Promise<T> {
  const headers = new Headers(init.headers);
  headers.set('Accept', 'application/json');
  if (init.body) headers.set('Content-Type', 'application/json');
  if (API_KEY) {
    // Supabase expose plusieurs schémas : on précise toujours `api`
    headers.set('apikey', API_KEY);
    headers.set('Accept-Profile', 'api');
    if (init.body) headers.set('Content-Profile', 'api');
  }
  const s = who ? session(who) : null;
  if (s) headers.set('Authorization', `Bearer ${s.token}`);
  // Ancienne clé « anon » de Supabase (un JWT) : la passerelle l'attend aussi ici
  else if (API_KEY.startsWith('eyJ')) headers.set('Authorization', `Bearer ${API_KEY}`);

  let res: Response;
  try {
    res = await fetch(`${API_URL}${path}`, { ...init, headers, credentials: 'omit' });
  } catch {
    throw new ApiError('Serveur injoignable. Vérifiez votre connexion.', 0);
  }

  // Jeton expiré, compte suspendu ou désactivé : retour à la connexion
  if (who && (res.status === 401 || res.status === 403)) {
    logout(who);
    location.hash = LOGIN_ROUTES[who];
  }
  if (!res.ok) {
    let message = `Erreur ${res.status}`;
    try {
      const body = await res.json();
      if (body?.message) message = body.message;
    } catch {
      /* corps vide */
    }
    throw new ApiError(message.charAt(0).toUpperCase() + message.slice(1), res.status);
  }
  if (res.status === 204) return undefined as T;
  const text = await res.text();
  return (text ? JSON.parse(text) : undefined) as T;
}

function rpc<T>(name: string, args: object, who: Who = 'organizer'): Promise<T> {
  return call<T>(`/rpc/${name}`, { method: 'POST', body: JSON.stringify(args) }, who);
}

export async function login(email: string, password: string): Promise<Session> {
  const s = await call<Session>('/rpc/login', {
    method: 'POST',
    body: JSON.stringify({ email, password }),
  }, null);
  saveSession(s, 'organizer');
  return s;
}

export const api = {
  myEvents: () => call<MyEvent[]>('/my_events?order=starts_at.desc'),
  myEvent: async (id: string) => {
    const rows = await call<MyEvent[]>(`/my_events?id=eq.${encodeURIComponent(id)}`);
    if (!rows.length) throw new ApiError('Manifestation introuvable', 404);
    return rows[0];
  },
  create: (input: EventInput) => rpc<string>('create_event', input),
  update: (id: string, input: EventInput) => rpc<void>('update_event', { id, ...input }),
  publish: (id: string) => rpc<void>('publish_event', { id }),
  cancel: (id: string) => rpc<void>('cancel_event', { id }),
  deleteDraft: (id: string) => rpc<void>('delete_draft', { id }),
  changePassword: (current: string, next: string) =>
    rpc<void>('change_password', { current_password: current, new_password: next }),
};


// Administration ------------------------------------------------------
// Jamais de donnée de participant : comptes organisateurs, manifs et totaux.

export interface GroupStats {
  city?: string;
  cause?: CauseId;
  events: number;
  present: number;
  supporters: number;
}

export interface AdminOverview {
  organizers: { active: number; suspended: number };
  events: { draft: number; upcoming: number; live: number; ended: number; cancelled: number; hidden: number };
  totals: { present: number; supporters: number };
  by_city: GroupStats[];
  by_cause: GroupStats[];
  health: {
    tokens_stored: number;
    overdue_purges: number;
    next_purge: string | null;
    last_cron: { status: string; at: string | null; message: string | null } | null;
    database_size: string;
    checked_at: string;
  };
}

export interface AdminEvent {
  id: string;
  title: string;
  cause: CauseId;
  city: string;
  starts_at: string;
  ends_at: string;
  status: Status;
  declared: boolean;
  organizer_id: string;
  organizer: string;
  hidden_at: string | null;
  hidden_reason: string | null;
  purged_at: string | null;
  present: number | null;
  supporters: number | null;
}

export interface AdminOrganizer {
  id: string;
  name: string;
  email: string;
  created_at: string;
  suspended_at: string | null;
  suspended_reason: string | null;
  events: number;
  drafts: number;
}

export interface AdminLogEntry {
  at: string;
  admin: string;
  action: string;
  target_kind: 'organizer' | 'event';
  target_id: string;
  target: string | null;
  reason: string | null;
}

export async function adminLogin(email: string, password: string, code: string): Promise<Session> {
  const s = await call<Session>('/rpc/admin_login', {
    method: 'POST',
    body: JSON.stringify({ email, password, code }),
  }, null);
  saveSession(s, 'admin');
  return s;
}

export const adminApi = {
  overview: () => call<AdminOverview>('/rpc/admin_overview', {}, 'admin'),
  events: () => call<AdminEvent[]>('/rpc/admin_events', {}, 'admin'),
  organizers: () => call<AdminOrganizer[]>('/rpc/admin_organizers', {}, 'admin'),
  log: () => call<AdminLogEntry[]>('/rpc/admin_log', {}, 'admin'),
  invite: (name: string, email: string) =>
    rpc<{ id: string; password: string }>('admin_invite_organizer', { name, email }, 'admin'),
  resetPassword: (id: string) => rpc<{ password: string }>('admin_reset_password', { id }, 'admin'),
  suspend: (id: string, reason: string) => rpc<void>('admin_suspend_organizer', { id, reason }, 'admin'),
  reactivate: (id: string) => rpc<void>('admin_reactivate_organizer', { id }, 'admin'),
  hide: (id: string, reason: string) => rpc<void>('admin_hide_event', { id, reason }, 'admin'),
  unhide: (id: string) => rpc<void>('admin_unhide_event', { id }, 'admin'),
};
