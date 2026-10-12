---
name: revue-vie-privee
description: Checklist de vie privée à appliquer avant tout changement qui touche aux données des participants (app, API, SQL, serveur, dépendances, logs). À utiliser aussi pour relire une PR.
---

# Revue vie privée Foulala

Les données de Foulala révèlent des opinions politiques. Appliquer cette checklist à tout changement qui touche :
l'envoi de présence ou de soutien, le stockage local des jetons, les vues ou fonctions SQL, `server/`, les dépendances de l'app, ou tout ce qui journalise.

## 1. Ce qui sort du téléphone

- [ ] Seuls `event_id`, `token`, `time_slot` (multiple de 15 min) et `segment` partent vers le serveur.
- [ ] Aucune coordonnée, aucune précision GPS, aucune heure exacte, aucun identifiant d'appareil, aucun en-tête permettant d'identifier l'utilisateur.
- [ ] Le jeton est différent pour chaque manif, et jamais dérivé d'un identifiant stable (pas de hash de l'id de l'appareil).
- [ ] Aucune requête vers un tiers : pas d'analytics, de crash reporting avec IP, de polices ou tuiles chargées depuis un service qui journalise sans nécessité.

## 2. Ce que le serveur garde

- [ ] Aucune nouvelle colonne horodatée ou identifiante dans `presence` ou `support`.
- [ ] Aucune vue `api` n'expose un e-mail, un jeton ou une ligne individuelle.
- [ ] Tout nouvel agrégat géographique ou temporel applique le **seuil de 20**.
- [ ] La purge (`purge_event`) couvre toute nouvelle table qui contient des jetons.

## 3. Journaux

- [ ] Pas de directive `log` dans le Caddyfile, `X-Forwarded-For` toujours retiré.
- [ ] `PGRST_LOG_LEVEL` reste à `crit`, `log_connections` et `log_statement` restent désactivés.
- [ ] Aucun proxy ou CDN tiers devant l'API.
- [ ] La limite de débit reste en mémoire.

## 4. Recoupements possibles

Se demander : en combinant ce changement avec ce qui existe déjà, peut-on relier une personne à une manif ? Peut-on relier deux participations d'une même personne ? Peut-on isoler un petit groupe ?

Si oui à l'une de ces questions : ne pas fusionner, et proposer une alternative (agrégation, arrondi, seuil, calcul sur l'appareil).

## Sortie attendue

Un court rapport : points vérifiés, risques trouvés avec le fichier et la ligne concernés, et la correction proposée.
