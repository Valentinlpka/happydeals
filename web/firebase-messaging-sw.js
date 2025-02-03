importScripts(
  "https://www.gstatic.com/firebasejs/9.10.0/firebase-app-compat.js"
);
importScripts(
  "https://www.gstatic.com/firebasejs/9.10.0/firebase-messaging-compat.js"
);

firebase.initializeApp({
  apiKey: "AIzaSyAF_EaXi4OI5SEndI-Phe4FfJ6P7M5MaoA",
  authDomain: "happy-deals-3f03d.firebaseapp.com",
  projectId: "happy-deals-3f03d",
  storageBucket: "happy-deals-3f03d.appspot.com",
  messagingSenderId: "289031542511",
  appId: "1:289031542511:web:e608b4fb09685d0d8b6d1a",
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log("Received background message:", payload);
  return self.registration.showNotification(payload.notification.title, {
    body: payload.notification.body,
    icon: "./icons/Icon-512.png",
  });
});
