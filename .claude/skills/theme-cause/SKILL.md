---
name: theme-cause
description: Ajouter ou modifier une cause de manifestation (Climat, Fiertés, Paix, Social, Santé, Éducation…) et son thème visuel de façon cohérente entre design, base, app et page web.
---

# Ajouter ou modifier une cause

Chaque manif a une cause choisie par l'organisateur. La cause donne à la manif sa couleur, son icône et son motif dans toute l'app.

## Source de vérité

`design/tokens.json`, clé `causes`. Chaque cause définit :
- `primary` : boutons, puces, tracé du parcours. Texte blanc dessus, contraste de 4,5:1 minimum ;
- `deep` : texte coloré sur fond clair, 4,5:1 minimum sur `soft` ;
- `soft` : fond des écrans et des puces ;
- `mid` : zone de présence sur la carte, décor ;
- `pop` : accent (créneau en cours sur le graphique, marqueur d'arrivée). Doit se distinguer de `primary` par la luminosité, pas seulement par la teinte ;
- `stripe` : bande décorative sous la carte ;
- `scale` : 4 teintes de clair à foncé pour la carte de densité ;
- `icon` : nom de l'icône (trait, pas d'emoji).

## Étapes

1. Ajouter la cause dans `design/tokens.json`, avec un identifiant en minuscules sans accent (`education`).
2. Vérifier les contrastes : blanc sur `primary` et `deep` sur `soft` à 4,5:1 minimum.
3. Base : quand la colonne `event.cause` existera, ajouter la valeur à son type énuméré ou à sa contrainte, avec un test.
4. App et page web : générer ou mettre à jour les thèmes depuis `tokens.json`, sans recopier les couleurs à la main.
5. Garder une cause **Autre** au thème neutre pour les manifs qui ne rentrent dans aucune case.

## Règles

- Neutralité : aucune cause n'est mise en avant par rapport aux autres.
- Le thème habille la manif, il ne change jamais le fonctionnement du comptage.
- Pas de symbole protégé ni de logo d'organisation existante.
