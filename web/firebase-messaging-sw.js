// Dedicated Firebase Messaging service worker. Use an isolated scope under
// /VISCERA/ so it does not interfere with Flutter's web bootstrap/cache.
importScripts("https://www.gstatic.com/firebasejs/13.0.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/13.0.0/firebase-messaging-compat.js");
importScripts("./viscera_firebase_config.js");

firebase.initializeApp(self.visceraFirebaseConfig);
firebase.messaging();

// Firebase displays the notification payload when the page is in background.
// Do not echo patient information or display a duplicate notification here.
