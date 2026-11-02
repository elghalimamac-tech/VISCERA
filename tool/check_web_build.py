#!/usr/bin/env python3
"""Vérification minimale de la version Flutter Web avant déploiement GitHub Pages."""
from pathlib import Path
import sys

base = Path('build/web')
html_path = base / 'index.html'
required = [html_path, base / 'flutter_bootstrap.js',
            base / 'main.dart.js', base / 'manifest.json',
            base / 'firebase-messaging-sw.js',
            base / 'viscera_firebase_config.js',
            base / 'viscera_push_web.js']
missing = [str(f) for f in required if not f.is_file() or f.stat().st_size == 0]
if missing:
    sys.exit('Build Web incomplet : ' + ', '.join(missing))

html = html_path.read_text(encoding='utf-8')
if '<base href="/VISCERA/">' not in html:
    sys.exit('Chemin GitHub Pages incorrect : /VISCERA/ attendu')
if 'src="flutter_bootstrap.js"' not in html:
    sys.exit('Bootstrap Flutter absent du HTML')
if 'viscera-loading' not in html:
    sys.exit('Ecran de chargement/erreur manquant')
if 'src="viscera_push_web.js"' not in html:
    sys.exit('Pont Firebase web absent de la page')
if 'src="viscera_firebase_config.js"' not in html:
    sys.exit('Configuration Firebase web absente de la page')

service_worker = (base / 'firebase-messaging-sw.js').read_text(encoding='utf-8')
bridge = (base / 'viscera_push_web.js').read_text(encoding='utf-8')
if 'firebase.messaging()' not in service_worker:
    sys.exit('Service worker FCM non initialise')
if 'serviceWorkerRegistration: registration' not in bridge:
    sys.exit('Le service worker FCM doit avoir un scope explicite (GitHub Pages)')
if 'document.baseURI' not in bridge:
    sys.exit('Le service worker doit etre installe dans /VISCERA/')


# Le moteur graphique doit être servi par GitHub Pages, et non par un CDN.
for asset in ('canvaskit/canvaskit.wasm', 'canvaskit/canvaskit.js'):
    candidate = base / asset
    if not candidate.is_file() or candidate.stat().st_size == 0:
        sys.exit('CanvasKit local manquant : ' + asset)

bootstrap = (base / 'flutter_bootstrap.js').read_text(encoding='utf-8')
if '{{flutter_js}}' in bootstrap or '{{flutter_build_config}}' in bootstrap:
    sys.exit('Tokens Flutter non substitués dans le bootstrap')
if "canvasKitBaseUrl: 'canvaskit/'" not in bootstrap:
    sys.exit('Flutter doit charger CanvasKit localement')
if 'clearOldFlutterServiceWorker' not in bootstrap:
    sys.exit('Ancien service worker Flutter non nettoyé')
if 'viscera-compatible' not in html or 'visceraStartupFailed' not in html:
    sys.exit('Boutons de récupération du démarrage manquants')
if 'firebase-app-compat.js' in html or 'firebase-messaging-compat.js' in html:
    sys.exit('Le SDK Firebase ne doit pas bloquer le rendu de VISCERA')


print('VISCERA Web OK : scripts FCM présents, sous-chemin /VISCERA/, écran de secours présent.')
