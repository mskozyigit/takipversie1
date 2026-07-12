// Combined Service Worker for TakipVersie1
// - Caches core Flutter assets for fast repeat loads on mobile (3G/4G)
// - Handles Firebase Cloud Messaging background notifications
// - Cache-first strategy for static assets, network-only for Firestore

// Cache version — bump this on each deploy to force cache refresh
const CACHE_NAME = 'takipversie1-v2';

// --- FCM Setup ---
try {
  importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js');
  importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js');
} catch (e) {
  console.warn('[SW] Failed to load Firebase SDKs:', e);
}

if (typeof firebase !== 'undefined') {
  firebase.initializeApp({
    apiKey: 'AIzaSyAvYpS7WUO0ZV-5ApEu4uhpLUot2G5WkDA',
    appId: '1:801307611460:web:a4b2154354861a5ac9c711',
    messagingSenderId: '801307611460',
    projectId: 'takipversi1',
    authDomain: 'takipversi1.firebaseapp.com',
    storageBucket: 'takipversi1.firebasestorage.app',
  });

  const messaging = firebase.messaging();
  messaging.onBackgroundMessage((payload) => {
    self.registration.showNotification(payload.notification.title, {
      body: payload.notification.body,
      icon: '/takipversie1/icons/Icon-192.png',
    });
  });
}

// --- Cache Strategy (mobile-first) ---
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return Promise.allSettled([
        '/takipversie1/',
        '/takipversie1/main.dart.js',
        '/takipversie1/flutter_bootstrap.js',
        '/takipversie1/manifest.json',
        '/takipversie1/icons/Icon-192.png',
        '/takipversie1/icons/Icon-512.png',
      ].map(url => cache.add(url).catch(err => {
        console.warn('[SW] Failed to cache:', url, err);
      })));
    }).then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) => {
      return Promise.all(
        keys.filter((key) => key !== CACHE_NAME).map((key) => caches.delete(key))
      );
    }).then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (event) => {
  // Skip Firebase API calls — always go to network for real-time data
  const url = event.request.url;
  if (url.includes('firestore') || url.includes('googleapis') ||
      url.includes('firebaseio') || url.includes('google.com') ||
      url.includes('gstatic.com')) {
    return; // Browser handles normally
  }

  // Cache-first for static Flutter assets
  event.respondWith(
    caches.match(event.request).then((cached) => {
      return cached || fetch(event.request).then((response) => {
        if (response.status === 200) {
          const clone = response.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put(event.request, clone));
        }
        return response;
      });
    })
  );
});
