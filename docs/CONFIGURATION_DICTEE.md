# Configurer la dictée vocale Flutter (Android / iOS)

La fonction « micro » de VISCERA V9 utilise `speech_to_text` (reconnaissance vocale du système). Elle est prévue pour des dictées **courtes**, par champ. Les résultats sont des brouillons éditables et **l'audio n'est pas archivé par VISCERA**. Le moteur vocal du système peut néanmoins utiliser des serveurs distants selon l'appareil et ses réglages. Ne pas y saisir de données médicales réelles avant évaluation et validation de la confidentialité par l'établissement.

Après génération du squelette natif par `flutter create --platforms=android,ios .` :

## Android

Dans `android/app/src/main/AndroidManifest.xml`, dans l'élément `<manifest>` et hors de `<application>`, ajouter :

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.INTERNET" />
<queries>
    <intent>
        <action android:name="android.speech.RecognitionService" />
    </intent>
</queries>
```

## iOS

Dans `ios/Runner/Info.plist`, dans `<dict>` :

```xml
<key>NSMicrophoneUsageDescription</key>
<string>La dictée permet de saisir puis corriger une observation clinique.</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>La reconnaissance vocale transforme la dictée en texte à vérifier.</string>
```

Sur l'appareil, autoriser le micro et la reconnaissance vocale ; tester la disponibilité de la locale `fr_FR` et le comportement réseau du moteur vocal choisi. La dictée ne doit jamais confirmer un compte rendu, une ordonnance ou un report sur Magica/Sillage à la place du professionnel.

## Limites

- La reconnaissance dépend du système d'exploitation, du service installé, des autorisations et de la langue disponible. Pas de garantie de fonctionnement hors ligne.
- Le moteur est destiné à de courtes séquences vocales et peut s'arrêter après une pause : redémarrer le micro pour dicter la suite.
- Chiffrement du dossier, gestion des rôles, logs, sauvegardes et éventuelle infrastructure de transcription maîtrisée restent nécessaires avant tout déploiement clinique.
