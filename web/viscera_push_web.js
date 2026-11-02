// Browser bridge for Flutter Web push. A custom SW registration is mandatory
// for GitHub Pages under /VISCERA/ (FCM's default root worker cannot be used).
(function (w) {
  "use strict";
  let messaging = null;
  let currentToken = null;

  function showGenericForegroundNotice() {
    const existing = document.getElementById("viscera-web-push-notice");
    if (existing) existing.remove();
    const notice = document.createElement("div");
    notice.id = "viscera-web-push-notice";
    notice.setAttribute("role", "status");
    notice.textContent = "Nouvelle notification VISCERA";
    Object.assign(notice.style, {
      position: "fixed", top: "18px", right: "18px", zIndex: "10001",
      background: "#083B46", color: "#fff", padding: "12px 16px",
      borderRadius: "10px", fontFamily: "system-ui, sans-serif",
      boxShadow: "0 3px 14px rgba(0,0,0,.18)"
    });
    document.body.appendChild(notice);
    setTimeout(() => notice.remove(), 5500);
  }

  // Firebase CDN ne doit JAMAIS bloquer l'ouverture de l'application médicale.
  // Chargement seulement quand le médecin demande les notifications Web.
  let sdkPromise = null;
  function loadScript(url) {
    return new Promise((resolve, reject) => {
      const script = document.createElement("script");
      script.src = url;
      script.async = true;
      script.onload = resolve;
      script.onerror = () => reject(new Error("Bibliothèque Firebase indisponible"));
      document.head.appendChild(script);
    });
  }
  function ensureFirebaseSdk() {
    if (w.firebase && w.firebase.messaging) return Promise.resolve();
    if (!sdkPromise) {
      sdkPromise = loadScript("https://www.gstatic.com/firebasejs/13.0.0/firebase-app-compat.js")
        .then(() => loadScript("https://www.gstatic.com/firebasejs/13.0.0/firebase-messaging-compat.js"));
    }
    return sdkPromise;
  }

  function getMessaging() {
    if (!w.firebase || !w.firebase.messaging || !w.visceraFirebaseConfig) {
      throw new Error("Firebase Web n'est pas chargé.");
    }
    if (!messaging) {
      const app = w.firebase.apps.find((candidate) => candidate.name === "viscera-web-push") ||
          w.firebase.initializeApp(w.visceraFirebaseConfig, "viscera-web-push");
      messaging = w.firebase.messaging(app);
      messaging.onMessage(showGenericForegroundNotice);
    }
    return messaging;
  }

  w.visceraWebPushPermission = function () {
    if (!w.isSecureContext || !("serviceWorker" in navigator) ||
        !("Notification" in w) || !("PushManager" in w)) {
      return "unsupported";
    }
    return Notification.permission;
  };

  w.visceraWebPushCurrentToken = function () {
    return currentToken;
  };

  w.visceraWebPushSubscribe = async function (vapidKey) {
    if (w.visceraWebPushPermission() === "unsupported") {
      throw new Error("Ce navigateur ne prend pas en charge les notifications Web.");
    }
    // Invoke from a real user click when the permission has not been granted.
    if (Notification.permission !== "granted") {
      const decision = await Notification.requestPermission();
      if (decision !== "granted") {
        throw new Error("Autorisez les notifications dans les paramètres du navigateur.");
      }
    }
    await ensureFirebaseSdk();
    if (!(await w.firebase.messaging.isSupported())) {
      throw new Error("Firebase Messaging n'est pas disponible dans ce navigateur.");
    }
    const registration = await navigator.serviceWorker.register(
      new URL("firebase-messaging-sw.js", document.baseURI).toString(),
      {scope: new URL("fcm-push-scope/", document.baseURI).pathname}
    );
    const token = await getMessaging().getToken({
      vapidKey: vapidKey,
      serviceWorkerRegistration: registration
    });
    currentToken = token || null;
    return currentToken;
  };

  w.visceraWebPushDeleteToken = async function () {
    if (!messaging) return false;
    const success = await messaging.deleteToken();
    currentToken = null;
    return !!success;
  };
})(window);
