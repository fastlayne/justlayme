/**
 * JustLayMe Service Worker
 * Handles push notifications, background sync, and offline capabilities
 * @version 1.0.0
 */

const CACHE_NAME = 'justlayme-v1';
const OFFLINE_URL = '/offline.html';

// Assets to cache for offline access
const STATIC_ASSETS = [
  '/',
  '/index.html',
  '/offline.html'
];

// ============================================
// INSTALLATION & ACTIVATION
// ============================================

self.addEventListener('install', (event) => {
  console.log('[SW] Installing service worker...');

  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => {
        console.log('[SW] Caching static assets');
        return cache.addAll(STATIC_ASSETS);
      })
      .then(() => {
        console.log('[SW] Skip waiting on install');
        return self.skipWaiting();
      })
  );
});

self.addEventListener('activate', (event) => {
  console.log('[SW] Activating service worker...');

  event.waitUntil(
    Promise.all([
      // Clean up old caches
      caches.keys().then((cacheNames) => {
        return Promise.all(
          cacheNames.map((cacheName) => {
            if (cacheName !== CACHE_NAME) {
              console.log('[SW] Deleting old cache:', cacheName);
              return caches.delete(cacheName);
            }
          })
        );
      }),
      // Take control of all clients immediately
      self.clients.claim()
    ])
  );
});

// ============================================
// PUSH NOTIFICATION HANDLING
// ============================================

self.addEventListener('push', (event) => {
  console.log('[SW] Push received:', event);

  let notificationData = {
    title: 'JustLayMe',
    body: 'You have a new message!',
    icon: '/icons/icon-192.png',
    badge: '/icons/badge-72.png',
    tag: 'default',
    data: {}
  };

  // Parse push data if available
  if (event.data) {
    try {
      const payload = event.data.json();
      notificationData = {
        title: payload.title || notificationData.title,
        body: payload.body || notificationData.body,
        icon: payload.icon || notificationData.icon,
        badge: payload.badge || notificationData.badge,
        image: payload.image,
        tag: payload.tag || payload.type || 'default',
        data: payload.data || {},
        actions: payload.actions || [],
        requireInteraction: payload.requireInteraction || false,
        silent: payload.silent || false,
        vibrate: payload.vibrate || [200, 100, 200],
        renotify: payload.renotify || false
      };
    } catch (e) {
      console.error('[SW] Error parsing push data:', e);
      notificationData.body = event.data.text();
    }
  }

  // Track notification received
  trackNotificationEvent('received', notificationData);

  // Show the notification
  const promiseChain = self.registration.showNotification(
    notificationData.title,
    {
      body: notificationData.body,
      icon: notificationData.icon,
      badge: notificationData.badge,
      image: notificationData.image,
      tag: notificationData.tag,
      data: notificationData.data,
      actions: notificationData.actions,
      requireInteraction: notificationData.requireInteraction,
      silent: notificationData.silent,
      vibrate: notificationData.vibrate,
      renotify: notificationData.renotify,
      timestamp: Date.now()
    }
  );

  event.waitUntil(promiseChain);
});

// ============================================
// NOTIFICATION CLICK HANDLING (Deep Linking)
// ============================================

self.addEventListener('notificationclick', (event) => {
  console.log('[SW] Notification clicked:', event);

  const notification = event.notification;
  const action = event.action;
  const data = notification.data || {};

  // Close the notification
  notification.close();

  // Track notification click
  trackNotificationEvent('clicked', {
    tag: notification.tag,
    action: action,
    data: data
  });

  // Determine the URL to open based on action and data
  let targetUrl = '/';

  if (action) {
    // Handle action button clicks
    switch (action) {
      case 'reply':
        targetUrl = data.conversationUrl || `/?conversation=${data.conversationId}`;
        break;
      case 'view':
        targetUrl = data.url || '/';
        break;
      case 'dismiss':
        // Just close, don't navigate
        return;
      case 'settings':
        targetUrl = '/?modal=settings&tab=notifications';
        break;
      default:
        targetUrl = data.url || '/';
    }
  } else {
    // Default click behavior - use deep link data
    if (data.deepLink) {
      targetUrl = data.deepLink;
    } else if (data.conversationId) {
      targetUrl = `/?conversation=${data.conversationId}`;
    } else if (data.characterId) {
      targetUrl = `/?character=${data.characterId}`;
    } else if (data.url) {
      targetUrl = data.url;
    }
  }

  // Open or focus the appropriate window
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true })
      .then((clientList) => {
        // Check if there's already an open window
        for (const client of clientList) {
          if (client.url.includes(self.registration.scope) && 'focus' in client) {
            // Navigate existing window
            return client.navigate(targetUrl).then(() => client.focus());
          }
        }
        // Open new window if none exists
        if (clients.openWindow) {
          return clients.openWindow(targetUrl);
        }
      })
  );
});

// ============================================
// NOTIFICATION CLOSE HANDLING
// ============================================

self.addEventListener('notificationclose', (event) => {
  console.log('[SW] Notification closed:', event);

  const notification = event.notification;

  // Track notification dismissal
  trackNotificationEvent('dismissed', {
    tag: notification.tag,
    data: notification.data
  });
});

// ============================================
// SILENT PUSH HANDLING
// ============================================

self.addEventListener('push', (event) => {
  if (!event.data) return;

  try {
    const payload = event.data.json();

    // Check if this is a silent push
    if (payload.silent === true && payload.type === 'background-update') {
      console.log('[SW] Silent push received:', payload);

      event.waitUntil(
        handleSilentPush(payload)
      );
    }
  } catch (e) {
    // Not JSON or not a silent push
  }
});

async function handleSilentPush(payload) {
  const action = payload.action;

  switch (action) {
    case 'sync-messages':
      await syncMessages();
      break;
    case 'update-badge':
      await updateBadge(payload.count);
      break;
    case 'prefetch-content':
      await prefetchContent(payload.urls);
      break;
    case 'clear-cache':
      await clearOldCache();
      break;
    default:
      console.log('[SW] Unknown silent push action:', action);
  }

  // Notify all clients about the background update
  const clients = await self.clients.matchAll({ type: 'window' });
  clients.forEach(client => {
    client.postMessage({
      type: 'SILENT_PUSH_HANDLED',
      action: action,
      timestamp: Date.now()
    });
  });
}

// ============================================
// BACKGROUND SYNC
// ============================================

self.addEventListener('sync', (event) => {
  console.log('[SW] Background sync triggered:', event.tag);

  switch (event.tag) {
    case 'sync-messages':
      event.waitUntil(syncMessages());
      break;
    case 'sync-preferences':
      event.waitUntil(syncPreferences());
      break;
    case 'send-pending-messages':
      event.waitUntil(sendPendingMessages());
      break;
    case 'sync-analytics':
      event.waitUntil(syncAnalytics());
      break;
    default:
      console.log('[SW] Unknown sync tag:', event.tag);
  }
});

async function syncMessages() {
  console.log('[SW] Syncing messages...');

  try {
    // Get the auth token from IndexedDB
    const db = await openDatabase();
    const token = await getFromDB(db, 'auth', 'token');

    if (!token) {
      console.log('[SW] No auth token, skipping sync');
      return;
    }

    const response = await fetch('/api/conversations?limit=10', {
      headers: {
        'Authorization': `Bearer ${token}`
      }
    });

    if (response.ok) {
      const data = await response.json();
      // Cache the latest conversations
      await saveToCache('conversations', data);

      // Notify clients
      const clients = await self.clients.matchAll({ type: 'window' });
      clients.forEach(client => {
        client.postMessage({
          type: 'MESSAGES_SYNCED',
          data: data
        });
      });
    }
  } catch (error) {
    console.error('[SW] Error syncing messages:', error);
  }
}

async function syncPreferences() {
  console.log('[SW] Syncing preferences...');

  try {
    const db = await openDatabase();
    const preferences = await getFromDB(db, 'preferences', 'notification-settings');

    if (preferences) {
      const token = await getFromDB(db, 'auth', 'token');

      await fetch('/api/notifications/preferences', {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify(preferences)
      });
    }
  } catch (error) {
    console.error('[SW] Error syncing preferences:', error);
  }
}

async function sendPendingMessages() {
  console.log('[SW] Sending pending messages...');

  try {
    const db = await openDatabase();
    const pendingMessages = await getAllFromDB(db, 'pending-messages');

    for (const message of pendingMessages) {
      try {
        const response = await fetch('/api/chat', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${message.token}`,
            'X-Session-ID': message.sessionId
          },
          body: JSON.stringify({
            message: message.content,
            character_id: message.characterId,
            model: message.model
          })
        });

        if (response.ok) {
          // Remove from pending
          await deleteFromDB(db, 'pending-messages', message.id);

          // Notify client
          const clients = await self.clients.matchAll({ type: 'window' });
          clients.forEach(client => {
            client.postMessage({
              type: 'PENDING_MESSAGE_SENT',
              messageId: message.id
            });
          });
        }
      } catch (e) {
        console.error('[SW] Failed to send pending message:', e);
      }
    }
  } catch (error) {
    console.error('[SW] Error sending pending messages:', error);
  }
}

// ============================================
// PERIODIC BACKGROUND SYNC
// ============================================

self.addEventListener('periodicsync', (event) => {
  console.log('[SW] Periodic sync triggered:', event.tag);

  switch (event.tag) {
    case 'check-new-messages':
      event.waitUntil(checkNewMessages());
      break;
    case 'update-content':
      event.waitUntil(updateCachedContent());
      break;
    default:
      console.log('[SW] Unknown periodic sync tag:', event.tag);
  }
});

async function checkNewMessages() {
  console.log('[SW] Checking for new messages...');

  try {
    const db = await openDatabase();
    const token = await getFromDB(db, 'auth', 'token');
    const lastCheck = await getFromDB(db, 'sync', 'last-message-check') || 0;

    if (!token) return;

    const response = await fetch(`/api/notifications/unread?since=${lastCheck}`, {
      headers: {
        'Authorization': `Bearer ${token}`
      }
    });

    if (response.ok) {
      const data = await response.json();

      if (data.count > 0) {
        // Show notification for new messages
        await self.registration.showNotification('New Messages', {
          body: `You have ${data.count} unread message${data.count > 1 ? 's' : ''}`,
          icon: '/icons/icon-192.png',
          badge: '/icons/badge-72.png',
          tag: 'new-messages',
          data: { url: '/' }
        });
      }

      // Update last check time
      await saveToDB(db, 'sync', 'last-message-check', Date.now());
    }
  } catch (error) {
    console.error('[SW] Error checking new messages:', error);
  }
}

// ============================================
// BACKGROUND FETCH
// ============================================

self.addEventListener('backgroundfetchsuccess', (event) => {
  console.log('[SW] Background fetch success:', event.registration.id);

  event.waitUntil(
    (async () => {
      const cache = await caches.open(CACHE_NAME);
      const records = await event.registration.matchAll();

      for (const record of records) {
        const response = await record.responseReady;
        await cache.put(record.request, response);
      }

      // Notify completion
      await event.updateUI({
        title: 'Download Complete',
        icons: [{ src: '/icons/icon-192.png', sizes: '192x192' }]
      });
    })()
  );
});

self.addEventListener('backgroundfetchfail', (event) => {
  console.error('[SW] Background fetch failed:', event.registration.id);
});

self.addEventListener('backgroundfetchabort', (event) => {
  console.log('[SW] Background fetch aborted:', event.registration.id);
});

self.addEventListener('backgroundfetchclick', (event) => {
  console.log('[SW] Background fetch clicked:', event.registration.id);

  event.waitUntil(
    clients.openWindow('/')
  );
});

// ============================================
// FETCH HANDLING (Offline Support)
// ============================================

self.addEventListener('fetch', (event) => {
  // Skip non-GET requests
  if (event.request.method !== 'GET') return;

  // Skip API requests from caching (let them fail naturally)
  if (event.request.url.includes('/api/')) return;

  event.respondWith(
    caches.match(event.request)
      .then((response) => {
        if (response) {
          // Return cached response
          return response;
        }

        // Fetch from network
        return fetch(event.request)
          .then((response) => {
            // Don't cache non-successful responses
            if (!response || response.status !== 200 || response.type !== 'basic') {
              return response;
            }

            // Clone and cache the response
            const responseToCache = response.clone();
            caches.open(CACHE_NAME)
              .then((cache) => {
                cache.put(event.request, responseToCache);
              });

            return response;
          })
          .catch(() => {
            // Return offline page for navigation requests
            if (event.request.mode === 'navigate') {
              return caches.match(OFFLINE_URL);
            }
          });
      })
  );
});

// ============================================
// MESSAGE HANDLING (Client Communication)
// ============================================

self.addEventListener('message', (event) => {
  console.log('[SW] Message received:', event.data);

  const { type, data } = event.data;

  switch (type) {
    case 'SKIP_WAITING':
      self.skipWaiting();
      break;

    case 'CACHE_URLS':
      event.waitUntil(
        caches.open(CACHE_NAME).then((cache) => cache.addAll(data.urls))
      );
      break;

    case 'CLEAR_CACHE':
      event.waitUntil(
        caches.delete(CACHE_NAME)
      );
      break;

    case 'SHOW_NOTIFICATION':
      event.waitUntil(
        self.registration.showNotification(data.title, data.options)
      );
      break;

    case 'REGISTER_SYNC':
      if ('sync' in self.registration) {
        event.waitUntil(
          self.registration.sync.register(data.tag)
        );
      }
      break;

    case 'STORE_TOKEN':
      event.waitUntil(
        (async () => {
          const db = await openDatabase();
          await saveToDB(db, 'auth', 'token', data.token);
        })()
      );
      break;

    case 'STORE_PENDING_MESSAGE':
      event.waitUntil(
        (async () => {
          const db = await openDatabase();
          await saveToDB(db, 'pending-messages', data.id, data);
        })()
      );
      break;

    case 'GET_SUBSCRIPTION':
      event.waitUntil(
        self.registration.pushManager.getSubscription()
          .then((subscription) => {
            event.ports[0].postMessage({
              type: 'SUBSCRIPTION',
              subscription: subscription ? subscription.toJSON() : null
            });
          })
      );
      break;
  }
});

// ============================================
// ANALYTICS TRACKING
// ============================================

async function trackNotificationEvent(eventType, data) {
  console.log('[SW] Tracking notification event:', eventType, data);

  try {
    const db = await openDatabase();

    // Store event locally
    const event = {
      id: `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
      type: eventType,
      data: data,
      timestamp: Date.now()
    };

    await saveToDB(db, 'notification-analytics', event.id, event);

    // Try to send immediately
    const token = await getFromDB(db, 'auth', 'token');

    if (token) {
      await fetch('/api/notifications/analytics', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify(event)
      }).catch(() => {
        // Will be synced later
        console.log('[SW] Analytics will be synced later');
      });
    }
  } catch (error) {
    console.error('[SW] Error tracking notification event:', error);
  }
}

async function syncAnalytics() {
  console.log('[SW] Syncing analytics...');

  try {
    const db = await openDatabase();
    const events = await getAllFromDB(db, 'notification-analytics');
    const token = await getFromDB(db, 'auth', 'token');

    if (!token || events.length === 0) return;

    const response = await fetch('/api/notifications/analytics/batch', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`
      },
      body: JSON.stringify({ events })
    });

    if (response.ok) {
      // Clear synced events
      for (const event of events) {
        await deleteFromDB(db, 'notification-analytics', event.id);
      }
    }
  } catch (error) {
    console.error('[SW] Error syncing analytics:', error);
  }
}

// ============================================
// INDEXEDDB HELPERS
// ============================================

const DB_NAME = 'justlayme-sw';
const DB_VERSION = 1;

function openDatabase() {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(DB_NAME, DB_VERSION);

    request.onerror = () => reject(request.error);
    request.onsuccess = () => resolve(request.result);

    request.onupgradeneeded = (event) => {
      const db = event.target.result;

      // Create object stores
      if (!db.objectStoreNames.contains('auth')) {
        db.createObjectStore('auth');
      }
      if (!db.objectStoreNames.contains('preferences')) {
        db.createObjectStore('preferences');
      }
      if (!db.objectStoreNames.contains('pending-messages')) {
        db.createObjectStore('pending-messages', { keyPath: 'id' });
      }
      if (!db.objectStoreNames.contains('notification-analytics')) {
        db.createObjectStore('notification-analytics', { keyPath: 'id' });
      }
      if (!db.objectStoreNames.contains('sync')) {
        db.createObjectStore('sync');
      }
      if (!db.objectStoreNames.contains('cache')) {
        db.createObjectStore('cache');
      }
    };
  });
}

function getFromDB(db, storeName, key) {
  return new Promise((resolve, reject) => {
    const transaction = db.transaction(storeName, 'readonly');
    const store = transaction.objectStore(storeName);
    const request = store.get(key);

    request.onerror = () => reject(request.error);
    request.onsuccess = () => resolve(request.result);
  });
}

function getAllFromDB(db, storeName) {
  return new Promise((resolve, reject) => {
    const transaction = db.transaction(storeName, 'readonly');
    const store = transaction.objectStore(storeName);
    const request = store.getAll();

    request.onerror = () => reject(request.error);
    request.onsuccess = () => resolve(request.result);
  });
}

function saveToDB(db, storeName, key, value) {
  return new Promise((resolve, reject) => {
    const transaction = db.transaction(storeName, 'readwrite');
    const store = transaction.objectStore(storeName);
    const request = store.put(value, key);

    request.onerror = () => reject(request.error);
    request.onsuccess = () => resolve(request.result);
  });
}

function deleteFromDB(db, storeName, key) {
  return new Promise((resolve, reject) => {
    const transaction = db.transaction(storeName, 'readwrite');
    const store = transaction.objectStore(storeName);
    const request = store.delete(key);

    request.onerror = () => reject(request.error);
    request.onsuccess = () => resolve(request.result);
  });
}

async function saveToCache(key, data) {
  const db = await openDatabase();
  await saveToDB(db, 'cache', key, data);
}

async function updateCachedContent() {
  console.log('[SW] Updating cached content...');

  const cache = await caches.open(CACHE_NAME);

  // Re-fetch and cache static assets
  for (const url of STATIC_ASSETS) {
    try {
      const response = await fetch(url);
      if (response.ok) {
        await cache.put(url, response);
      }
    } catch (e) {
      console.error('[SW] Failed to update cache for:', url);
    }
  }
}

async function prefetchContent(urls) {
  if (!urls || !Array.isArray(urls)) return;

  const cache = await caches.open(CACHE_NAME);

  for (const url of urls) {
    try {
      const response = await fetch(url);
      if (response.ok) {
        await cache.put(url, response);
      }
    } catch (e) {
      console.error('[SW] Failed to prefetch:', url);
    }
  }
}

async function clearOldCache() {
  const cacheNames = await caches.keys();

  for (const name of cacheNames) {
    if (name !== CACHE_NAME) {
      await caches.delete(name);
    }
  }
}

async function updateBadge(count) {
  if ('setAppBadge' in navigator) {
    if (count > 0) {
      await navigator.setAppBadge(count);
    } else {
      await navigator.clearAppBadge();
    }
  }
}

console.log('[SW] Service Worker loaded');
