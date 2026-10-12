# Journal des décisions

Chaque choix important, avec sa raison. Ajouter une entrée plutôt que modifier une ancienne.

## 2026-10 · Vérification de la position sur le téléphone
La position GPS ne quitte jamais l'appareil. Le serveur envoie la zone, le téléphone vérifie et n'envoie qu'un jeton. C'est moins résistant à la triche qu'une vérification côté serveur, mais aucune base de positions n'existe, donc rien ne peut fuir.

## 2026-10 · Un jeton par manif
Un jeton fixe par appareil permettrait de relier toutes les manifs d'une personne. Un jeton par manif rend ces recoupements impossibles.

## 2026-10 · Chiffre plancher, pas estimation
On affiche « au moins X présents vérifiés ». Pas d'extrapolation : tout redressement serait contestable et ferait perdre la neutralité.

## 2026-10 · PostgREST plutôt qu'une API codée à la main
La logique vit en SQL, testée en SQL. PostgREST n'expose que le schéma `api`. Moins de code, donc moins de surface d'attaque et un code plus facile à auditer.

## 2026-10 · Hébergement sur un VPS européen, pas sur Supabase en production
La passerelle de Supabase journalise les adresses IP des requêtes, sans option documentée pour le désactiver. Supabase reste acceptable pour des tests entre amis.

## 2026-10 · Monorepo
Un seul dépôt pour la base, le serveur, l'app, la page web et la doc. Tout évolue ensemble et l'audit est plus simple. Pas d'outil de monorepo : les langages diffèrent.

## 2026-10 · Flutter pour l'app
Un seul code pour iOS et Android. Cartes OpenStreetMap via `flutter_map`.

## 2026-10 · Nom : Foulala
« Foule » + « oh là là ». Facile à dire et à transmettre, neutre politiquement, comprenable à l'étranger. Le bouton principal reste « J'y suis ! ». Écartés : Cortège (trop générique), J'y suis (domaine .fr pris), Unisson (confusion avec le syndicat britannique UNISON et Intel Unison), Fouloscopie (déjà utilisé).

## 2026-10 · Un thème visuel par cause
Climat, Fiertés, Paix, Social, Santé, Éducation, Autre. L'organisateur choisit, les couleurs suivent partout. Les manifs contre la guerre sont classées « Paix » : on nomme ce qu'on défend.

## 2026-10 · Architecture de l'app : MVVM officiel de Flutter, pas Bloc
Couches `data` (services et dépôts), `domain` (Dart pur) et `ui` (une vue et un `ChangeNotifier` par écran), injectées avec `provider`. Chaque paquet ajouté est du code tiers à auditer sur un téléphone qui touche à des opinions politiques : on en garde le moins possible. La logique sensible (test de zone, créneau, tronçon, jeton, file d'envoi) vit dans `domain`, testée sans framework. Écartés : Bloc (verbeux pour quatre écrans), Riverpod (une dépendance et un modèle mental de plus pour les contributeurs).

## 2026-10 · Polices embarquées dans l'app
Bricolage Grotesque, Figtree et IBM Plex Mono sont livrées avec l'app, sans le paquet `google_fonts` : il les téléchargerait depuis les serveurs de Google, qui verraient passer l'adresse IP de chaque utilisateur.
