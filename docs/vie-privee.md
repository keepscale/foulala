# Vie privée : ce que Foulala sait, et ce qu'il ne sait pas

Participer à une manifestation révèle une opinion politique. Le RGPD classe cette information parmi les données sensibles. Foulala est conçu pour ne **jamais** pouvoir relier une personne à une manifestation.

## Ce que le serveur reçoit

| Donnée | Exemple | Pourquoi |
|---|---|---|
| Identifiant de la manif | `3f2c…` | Savoir quelle manif compter |
| Jeton aléatoire | `7f3c91a2-…` | Compter chaque téléphone une seule fois |
| Quart d'heure | `15:00` | Montrer la montée en puissance |
| Tronçon (optionnel) | `4` | Montrer la répartition le long du parcours |

## Ce qu'il ne reçoit jamais

- Ta position GPS : la vérification se fait sur ton téléphone.
- Ton nom, ton e-mail, ton numéro : il n'y a pas de compte participant.
- L'heure exacte : seulement le quart d'heure.
- Un identifiant de ton téléphone : le jeton change à chaque manif, donc on ne peut pas relier tes participations entre elles.

## Ce qui est conservé, et combien de temps

- **Jetons** : supprimés 24 h après la fin de la manif. Ce délai laisse partir les envois retardés quand le réseau a saturé.
- **Totaux** (par quart d'heure et par tronçon) : conservés, ils ne contiennent aucune donnée individuelle.
- **Adresses IP** : jamais enregistrées. Le serveur n'a pas de journal d'accès, et aucun service tiers ne se trouve entre ton téléphone et le serveur.

## Les organisateurs

Ce sont les seuls comptes : nom du collectif, e-mail de contact, mot de passe chiffré. Leur e-mail n'est jamais rendu public.

## Vérifier par soi-même

Tout le code est ouvert. La structure de la base est dans [`db/schema.sql`](../db/schema.sql), la configuration du serveur dans [`server/`](../server).

*Ce document devra être complété par une politique de confidentialité formelle et une analyse d'impact (AIPD) avant toute utilisation en manifestation réelle.*
