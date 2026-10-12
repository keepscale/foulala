# Méthode de comptage

Ce document est public : la crédibilité du chiffre repose sur sa transparence.

## Ce que le chiffre veut dire

Foulala affiche **« au moins X présents vérifiés »**. C'est un **plancher**, pas une estimation de la foule totale. Seules les personnes qui ont l'app et ont appuyé sur « J'y suis ! » sont comptées. Le cortège réel est toujours plus nombreux.

## Comment une présence est vérifiée

1. L'organisateur trace le parcours. Le serveur en déduit une **zone** : le parcours élargi de 100 m de chaque côté (réglable de 20 à 500 m).
2. Le participant appuie sur « J'y suis ! ». Son téléphone lit sa position **une seule fois** et vérifie :
   - que la précision GPS est meilleure que 50 m ;
   - qu'il est dans la zone ;
   - qu'on est dans le créneau : de 30 minutes avant le départ jusqu'à la fin.
3. Si c'est le cas, le téléphone envoie un jeton aléatoire propre à cette manif. Le serveur compte les **jetons distincts**. Un même téléphone n'est donc compté qu'une fois, même s'il appuie plusieurs fois.

## Ce qui est publié

- Le total de présents et le total de soutiens (les soutiens ne sont pas vérifiés par GPS).
- Les arrivées par quart d'heure.
- La répartition le long du parcours par tronçons d'environ 200 m, uniquement pour les groupes d'**au moins 20 personnes**.

## Limites connues

- **Sous-estimation** : tout le monde n'a pas l'app, ou ne pense pas à l'utiliser.
- **Biais** : les utilisateurs de l'app ne représentent pas forcément l'ensemble des manifestants.
- **Triche** : un téléphone modifié peut falsifier sa position. L'attestation d'appareil (Play Integrity, App Attest) bloque les émulateurs et les robots, pas toutes les fraudes.
- **GPS** : entre les immeubles, la position peut être imprécise. Une personne réellement présente peut alors être refusée.

Ces limites sont la raison pour laquelle on parle de plancher et pas de total.
