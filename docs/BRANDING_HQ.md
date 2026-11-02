# VISCERA — Identité visuelle haute qualité (0.14.1)

Les anciens contours polygonaux simplifiés ont été remplacés par une
vectorisation fidèle de l'illustration VISCERA validée.

## Fichiers maîtres

- `assets/branding/viscera-symbol.svg` : monogramme vectoriel original, teintes bleu canard et turquoise, transparent.
- `assets/branding/viscera-symbol-light.svg` : variante claire pour les fonds sombres.
- `assets/branding/viscera-app-icon.svg` : icône avec les vagues turquoise, en SVG 1024 × 1024 de base.

Il faut conserver ces SVG dans la source. **Ne pas les remplacer par une capture
d'écran redimensionnée**, ce qui rend les bords flous.

## Utilisation

- Écrans Flutter Android et Web : `VisceraMark` et `VisceraBrandLockup` chargent le SVG directement via flutter_svg.
- Icônes natives APK : générées depuis les SVG par le script d'intégration du projet.
- Adaptive icon Android : deux couches indépendantes, fond à vagues et V transparent, avec icône monochrome correcte.
- Web/PWA : favicon et icônes 192, 512, 1024 px régénérées à chaque build ; le splash affiche la même icône que l'APK.
- iOS : les icônes haute définition sont produites à partir de la même illustration lors de la création de la cible iOS.

## Builds

Les workflows GitHub `pages.yml` et `android-apk.yml` lancent déjà
`python3 tool/apply_viscera_branding.py` : c'est le même générateur pour les
deux plateformes. Toute modification du monogramme maître se répercute
automatiquement aux futures compilations Web et APK.

Après déploiement Web, actualiser la PWA installée ou vider son cache si l'ancien
favicon apparaît encore. Pour Android, installer le nouvel APK 0.14.1 (+15).
