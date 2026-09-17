importScripts(
  "https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js"
);

importScripts(
  "https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js"
);

const firebaseConfig = {
  apiKey: "YOUR_API_KEY",
  authDomain: "rtoda-notification-syste-255ce.firebaseapp.com",
  projectId: "rtoda-notification-syste-255ce",
  storageBucket: "rtoda-notification-syste-255ce.firebasestorage.app",
  messagingSenderId: "1007174949215",
  appId: "1:1007174949215:web:e920e7ab9156c19990feea",
  measurementId: "G-E17DP12EMH"
};

firebase.initializeApp(firebaseConfig);

const messaging = firebase.messaging();

messaging.onBackgroundMessage(function(payload) {
  console.log(
    "[firebase-messaging-sw.js] Background message:",
    payload
  );

  const notification = payload.notification || {};

  self.registration.showNotification(
    notification.title || "RTODA",
    {
      body:
          notification.body ||
          "You have a new notification.",
      icon: "/icons/Icon-192.png"
    }
  );
});

