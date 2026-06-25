// Minimalni service worker: skipWaiting + clients.claim (posodobi se ob vsakem deployu).
self.addEventListener("install", (event) => {
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(self.clients.claim());
});
