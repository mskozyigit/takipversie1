// Combined Service Worker for TakipVersie1
// - Caches core Flutter assets for fast repeat loads on mobile (3G/4G)
// - Handles Firebase Cloud Messaging background notifications
// - Cache-first strategy for static assets, network-only for Firestore

// Cache version — bump this on each deploy to force cache refresh
const CACHE_NAME = 'takipversie1-v4';

// Static assets to pre-cache on install (mobile-first strategy)
const PRECACHE_URLS = [
  '/takipversie1/',
  '/takipversie1/index.html',
  '/takipversie1/main.dart.js',
  '/takipversie1/flutter_bootstrap.js',
  '/takipversie1/flutter.js',
  '/takipversie1/manifest.json',
  '/takipversie1/favicon.png',
  '/takipversie1/version.json',
  // Icons (PWA install + notifications)
  '/takipversie1/icons/Icon-192.png',
  '/takipversie1/icons/Icon-512.png',
  '/takipversie1/icons/Icon-maskable-192.png',
  '/takipversie1/icons/Icon-maskable-512.png',
  // Default language file (first-load critical path)
  '/takipversie1/assets/lang/tr.json',
];

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

  // -------------------------------------------------------------------
  // FCM Background Message Handler (Android 16 Heads-up Ready)
  //
  // Android 16 + Samsung OneUI / Xiaomi cihazlarda push bildirimlerinin
  // "heads-up" (pop-up) olarak görünmesi için SUNUCU TARAFINDA da
  // aşağıdaki FCM payload yapısı kullanılmalıdır:
  //
  // {
  //   "message": {
  //     "token": "...",
  //     "notification": { "title": "...", "body": "..." },
  //     "android": {
  //       "priority": "high",
  //       "notification": {
  //         "channel_id": "default",
  //         "priority": "high",
  //         "visibility": "public",
  //         "notification_priority": "PRIORITY_HIGH"
  //       }
  //     },
  //     "webpush": {
  //       "headers": { "Urgency": "high" }
  //     }
  //   }
  // }
  // -------------------------------------------------------------------

  messaging.onBackgroundMessage((payload) => {
    const title = payload.notification?.title || 'Yeni Bildirim';
    const body = payload.notification?.body || '';
    const jobId = payload.data?.jobId || 'general';
    const tag = payload.data?.tag || jobId;

    self.registration.showNotification(title, {
      body: body,
      icon: '/takipversie1/icons/Icon-192.png',
      badge: '/takipversie1/icons/Icon-192.png',
      tag: tag,
      requireInteraction: true,
      renotify: true,
      vibrate: [200, 100, 200],
      data: payload.data || {},
      timestamp: Date.now(),
      silent: false,
    });
  });
}

// --- Cache Strategy (mobile-first) ---
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return Promise.allSettled(
        PRECACHE_URLS.map(url => cache.add(url).catch(err => {
          console.warn('[SW] Failed to cache:', url, err);
        }))
      );
    }).then(() => self.skipWaiting())
  );
});

// --- Message Handler: SKIP_WAITING ---
// Flutter/web tarafından gönderilen SKIP_WAITING mesajını dinle.
// Yeni SW'yi hemen aktive eder ve tüm client'lara UPDATE_READY bildirir.
self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }
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
