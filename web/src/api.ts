// Client de l'API PostgREST. Le jeton de l'organisateur ne vit que le temps
// de l'onglet (sessionStorage) et expire de toute façon après 8 h côté serveur.

export const API_URL = (import.meta.env.VITE_API_URL as string | undefined)?.replace(/\/$/, '')
  ?? 'http://localhost:3000';

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

const SESSION_KEY = 'foulala.organisateur';

export class ApiError extends Error {
  constructor(message: string, readonly status: number) {
    super(message);
  }
}

export function session(): Session | null {
  try {
    const raw = sessionStorage.getItem(SESSION_KEY);
    if (!raw) return null;
    const s = JSON.parse(raw) as Session;
    if (new Date(s.expires_at).getTime() <= Date.now()) {
      sessionStorage.removeItem(SESSION_KEY);
      return null;
    }
    return s;
  } catch {
    return memorySession;
  }
}

// Repli si le navigateur refuse sessionStorage (navigation privée stricte)
let memorySession: Session | null = null;

function saveSession(s: Session | null): void {
  memorySession = s;
  try {
    if (s) sessionStorage.setItem(SESSION_KEY, JSON.stringify(s));
    else sessionStorage.removeItem(SESSION_KEY);
  } catch {
    /* mémoire seulement */
  }
}

export function logout(): void {
  saveSession(null);
}

async function call<T>(path: string, init: RequestInit = {}, auth = true): Promise<T> {
  const headers = new Headers(init.headers);
  headers.set('Accept', 'application/json');
  if (init.body) headers.set('Content-Type', 'application/json');
  const s = session();
  if (auth && s) headers.set('Authorization', `Bearer ${s.token}`);

  let res: Response;
  try {
    res = await fetch(`${API_URL}${path}`, { ...init, headers, credentials: 'omit' });
  } catch {
    throw new ApiError('Serveur injoignable. Vérifiez votre connexion.', 0);
  }

  if (res.status === 401 || (res.status === 403 && auth && path !== '/rpc/login')) {
    if (auth && path !== '/rpc/login') {
      logout();
      location.hash = '#/connexion';
    }
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

function rpc<T>(name: string, args: object): Promise<T> {
  return call<T>(`/rpc/${name}`, { method: 'POST', body: JSON.stringify(args) });
}

export async function login(email: string, password: string): Promise<Session> {
  const s = await call<Session>('/rpc/login', {
    method: 'POST',
    body: JSON.stringify({ email, password }),
  }, false);
  saveSession(s);
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
};
