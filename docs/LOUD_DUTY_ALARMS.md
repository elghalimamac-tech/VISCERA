# VISCERA — Alarmes de garde plein écran (Android)

## Comportement

- Les alarmes personnelles enregistrées sont déclenchées par AlarmManager Android, même sans Flutter au premier plan. Aucune information de patient dans les alarmes.
- Écran d'alarme complet sur écran verrouillé lorsque l'utilisateur a accordé la permission. Android peut préférer une notification prioritaire lorsque le téléphone est déverrouillé.
- Service au premier plan avec sonnerie VISCERA originale en boucle, utilisation audio USAGE_ALARM : volume « Alarme » et NON « Notifications ».
- La sonnerie s'arrête automatiquement après **trois minutes**.
- Boutons « Arrêter » et « Reporter de 10 minutes » dans l'écran d'alarme et la notification.
- Les alarmes sont reprogrammées après un redémarrage et après une mise à jour. Elles sont annulées lors d'une déconnexion.
- Mode discret disponible avec le même planning pour éviter les notifications en double.

## Autorisations

1. Autoriser les notifications VISCERA sur Android.
2. Autoriser les alarmes exactes ; sinon l'horaire peut être retardé.
3. Sur Android 14+, autoriser l'accès spécial « Notifications plein écran » depuis le raccourci VISCERA.
4. Augmenter soi-même le **volume Alarme** dans les réglages sonores Android. L'application indique le niveau, sans forcer le volume et sans contourner Ne pas déranger.

La permission plein écran reste sous le contrôle d'Android et de l'utilisateur.
En cas de refus ou de restrictions du téléphone, l'alarme peut être réduite
à une notification haute priorité.

## Tester sur un téléphone réel

Dans « Alarmes et notifications », régler le volume Alarme, autoriser le plein
écran puis appuyer sur « Tester la sonnerie forte et le plein écran ».
Faire aussi un essai avec l'écran verrouillé.

## Infrastructure

Le script tool/configure_duty_reminders_android.py copie les sources Kotlin natives
après la commande flutter create et génère un fichier WAV original dans res/raw.
Le son de 4,8 secondes est joué en boucle par le service Android.
Les permissions de réveil, le service média et l'activité plein écran sont
déclarés dans le manifeste Android généré.

L'interface Flutter Web conserve ses notifications ordinaires et ne peut pas
garantir une alarme système sonore en arrière-plan.
Ces alarmes ne remplacent pas les circuits hospitaliers pour les urgences vitales.
