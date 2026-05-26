// firebase-messaging-sw.js
// FCM web push service worker — hem foreground-bypass hem background bildirim.

importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyC6DUFFFHiIUByT0pIFxrqtDj4w4jFp-bI',
  authDomain: 'sehirden-koye.firebaseapp.com',
  projectId: 'sehirden-koye',
  storageBucket: 'sehirden-koye.firebasestorage.app',
  messagingSenderId: '167692479721',
  appId: '1:167692479721:web:7767e48648b23bb1701478',
});

const messaging = firebase.messaging();

// Sekme arka plandayken veya kapalıyken OS bildirimi göster.
messaging.onBackgroundMessage((payload) => {
  const notification = payload.notification || {};
  const title = notification.title || (payload.data && payload.data.title) || 'Köyden Şehre';
  const body  = notification.body  || (payload.data && payload.data.body)  || '';

  self.registration.showNotification(title, {
    body,
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
  });
});
