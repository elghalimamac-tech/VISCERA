{{flutter_js}}
{{flutter_build_config}}

(function () {
  'use strict';

  var status = function (message) {
    var element = document.getElementById('viscera-loading-message');
    if (element) element.textContent = message;
  };
  var fail = function (step) {
    if (typeof window.visceraStartupFailed === 'function') {
      window.visceraStartupFailed(step);
    } else {
      status('Impossible de démarrer VISCERA. Veuillez actualiser cette page.');
    }
  };
  var lowGraphics = new URLSearchParams(window.location.search)
      .get('viscera_cpu') === '1';

  // Toutes les variantes CanvasKit sont déjà produites dans build/web/canvaskit.
  // N'utilisez pas le CDN gstatic : sur certains réseaux mobiles il est bloqué.
  var config = {canvasKitBaseUrl: 'canvaskit/'};
  if (lowGraphics) config.canvasKitForceCpuOnly = true;

  async function clearOldFlutterServiceWorker() {
    if (!('serviceWorker' in navigator)) return false;
    // Les anciennes versions Flutter enregistrent un service worker qui peut
    // servir des fichiers JS périmés après la mise à jour GitHub Pages.
    var registrations;
    try {
      registrations = await Promise.race([
        navigator.serviceWorker.getRegistrations(),
        new Promise(function (resolve) { setTimeout(function () { resolve([]); }, 1800); })
      ]);
    } catch (_) {
      return false;
    }
    var oldWorkerUrl = new URL('flutter_service_worker.js', document.baseURI).href;
    var removed = false;
    for (var registration of registrations) {
      var workers = [registration.active, registration.waiting, registration.installing];
      if (workers.some(function (worker) {
        return worker && worker.scriptURL === oldWorkerUrl;
      })) {
        try {
          if (await registration.unregister()) removed = true;
        } catch (_) { /* Pas bloquant */ }
      }
    }
    if (removed && navigator.serviceWorker.controller) {
      try {
        var marker = 'viscera_legacy_worker_reloaded_v1';
        if (!sessionStorage.getItem(marker)) {
          sessionStorage.setItem(marker, '1');
          location.reload();
          return true;
        }
      } catch (_) { /* Navigation privée : continuer sans cache persistant */ }
    }
    return false;
  }

  async function start() {
    if (await clearOldFlutterServiceWorker()) return;
    status('Chargement du moteur graphique VISCERA…');
    await _flutter.loader.load({
    config: config,
    onEntrypointLoaded: async function (engineInitializer) {
      try {
        status('Initialisation de l’interface médicale…');
        // En cas d'onEntrypointLoaded explicite, le SDK Flutter ne transmet
        // pas automatiquement la configuration de load à initializeEngine.
        var appRunner = await engineInitializer.initializeEngine(config);
        status('Ouverture de VISCERA…');
        await appRunner.runApp();
        // L'événement flutter-first-frame retire normalement le splash.
        // Ce filet de sécurité évite le blocage d'un overlay HTML persistant.
        setTimeout(function () {
          if (document.querySelector('flutter-view, flt-glass-pane') &&
              typeof window.visceraStartupReady === 'function') {
            window.visceraStartupReady();
          }
        }, 1800);
      } catch (error) {
        console.error('VISCERA: erreur lors de l’initialisation Flutter', error);
        fail('initialisation');
      }
    }
    });
  }

  start().catch(function (error) {
    console.error('VISCERA: échec du chargement du code Flutter', error);
    fail('chargement');
  });
}());
