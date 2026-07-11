// Firebase Cloud Messaging Service Worker for Web Push Notifications
importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyAvYpS7WUO0ZV-5ApEu4uhpLUot2G5WkDA',
  appId: '1:801307611460:web:a4b2154354861a5ac9c711',
  messagingSenderId: '801307611460',
  projectId: 'takipversi1',
  authDomain: 'takipversi1.firebaseapp.com',
  storageBucket: 'takipversi1.firebasestorage.app',
  measurementId: 'G-1RKWW822K5',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message: ', payload),
  self.registration.showNotification(payload.notification.title, {
    body: payload.notification.body,
    icon: '/icons/Icon-192.png',
  }),
});
