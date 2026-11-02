#!/usr/bin/env python3
"""Vérification minimale de la version Flutter Web avant déploiement GitHub Pages."""
from pathlib import Path
import sys

base = Path('build/web')
html_path = base / 'index.html'
required = [html_path, base / 'flutter_bootstrap.js',
            base / 'main.dart.js', base / 'manifest.json']
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

print('VISCERA Web OK : scripts présents, sous-chemin /VISCERA/, écran de secours présent.')
