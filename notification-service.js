/**
 * JustLayMe Notification Service
 * Client-side library for managing push notifications, local notifications, and preferences
 * @version 1.0.0
 */

class NotificationService {
  constructor(options = {}) {
    this.vapidPublicKey = options.vapidPublicKey || null;
    this.serviceWorkerPath = options.serviceWorkerPath || '/sw.js';
    this.apiBaseUrl = options.apiBaseUrl || '';
    this.debug = options.debug || false;

    // State
    this.serviceWorkerRegistration = null;
    this.pushSubscription = null;
    this.isInitialized = false;
    this.preferences = this.loadPreferences();

    // Callbacks
    this.onPermissionChange = options.onPermissionChange || (() => {});
    this.onSubscriptionChange = options.onSubscriptionChange || (() => {});
    this.onNotificationReceived = options.onNotificationReceived || (() => {});
    this.onNotificationClicked = options.onNotificationClicked || (() => {});

    // Analytics
    this.analyticsQueue = [];
    this.analyticsFlushInterval = null;

    // Bind methods
    this.handleServiceWorkerMessage = this.handleServiceWorkerMessage.bind(this);
  }

  // ============================================
  // INITIALIZATION
  // ============================================

  async initialize() {
    if (this.isInitialized) return true;

    this.log('Initializing notification service...');

    // Check browser support
    if (!this.isSupported()) {
      console.warn('Push notifications are not supported in this browser');
      return false;
    }

    try {
      // Register service worker
      this.serviceWorkerRegistration = await navigator.serviceWorker.register(
        this.serviceWorkerPath,
        { scope: '/' }
      );

      this.log('Service Worker registered:', this.serviceWorkerRegistration);

      // Wait for service worker to be ready
      await navigator.serviceWorker.ready;

      // Listen for messages from service worker
      navigator.serviceWorker.addEventListener('message', this.handleServiceWorkerMessage);

      // Get existing subscription
      this.pushSubscription = await this.serviceWorkerRegistration.pushManager.getSubscription();

      // Start analytics flush interval
      this.startAnalyticsFlush();

      this.isInitialized = true;
      this.log('Notification service initialized');

      return true;
    } catch (error) {
      console.error('Failed to initialize notification service:', error);
      return false;
    }
  }

  // ============================================
  // BROWSER SUPPORT CHECKS
  // ============================================

  isSupported() {
    return 'serviceWorker' in navigator &&
           'PushManager' in window &&
           'Notification' in window;
  }

  isPushSupported() {
    return 'PushManager' in window;
  }

  isLocalNotificationSupported() {
    return 'Notification' in window;
  }

  isBackgroundSyncSupported() {
    return 'sync' in (this.serviceWorkerRegistration || {});
  }

  isPeriodicSyncSupported() {
    return 'periodicSync' in (this.serviceWorkerRegistration || {});
  }

  isBackgroundFetchSupported() {
    return 'backgroundFetch' in (this.serviceWorkerRegistration || {});
  }

  // ============================================
  // PERMISSION MANAGEMENT
  // ============================================

  getPermissionStatus() {
    if (!this.isLocalNotificationSupported()) return 'unsupported';
    return Notification.permission; // 'granted', 'denied', or 'default'
  }

  async requestPermission() {
    if (!this.isLocalNotificationSupported()) {
      return 'unsupported';
    }

    const currentPermission = this.getPermissionStatus();

    if (currentPermission === 'granted') {
      return 'granted';
    }

    if (currentPermission === 'denied') {
      return 'denied';
    }

    try {
      const permission = await Notification.requestPermission();
      this.onPermissionChange(permission);
      this.trackEvent('permission_requested', { result: permission });
      return permission;
    } catch (error) {
      console.error('Error requesting permission:', error);
      return 'error';
    }
  }

  // ============================================
  // PUSH SUBSCRIPTION
  // ============================================

  async subscribe(authToken = null) {
    this.log('Subscribing to push notifications...');

    if (!this.isInitialized) {
      await this.initialize();
    }

    if (!this.vapidPublicKey) {
      // Fetch VAPID key from server
      try {
        const response = await fetch(`${this.apiBaseUrl}/api/notifications/vapid-key`);
        const data = await response.json();
        this.vapidPublicKey = data.publicKey;
      } catch (error) {
        console.error('Failed to fetch VAPID key:', error);
        throw new Error('Could not get VAPID key from server');
      }
    }

    // Request permission first
    const permission = await this.requestPermission();
    if (permission !== 'granted') {
      throw new Error('Notification permission not granted');
    }

    try {
      // Convert VAPID key
      const applicationServerKey = this.urlBase64ToUint8Array(this.vapidPublicKey);

      // Subscribe to push
      this.pushSubscription = await this.serviceWorkerRegistration.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: applicationServerKey
      });

      this.log('Push subscription created:', this.pushSubscription);

      // Send subscription to server
      if (authToken) {
        await this.sendSubscriptionToServer(this.pushSubscription, authToken);
      }

      this.onSubscriptionChange(this.pushSubscription);
      this.trackEvent('push_subscribed', {});

      return this.pushSubscription;
    } catch (error) {
      console.error('Failed to subscribe to push:', error);
      throw error;
    }
  }

  async unsubscribe(authToken = null) {
    this.log('Unsubscribing from push notifications...');

    if (!this.pushSubscription) {
      this.log('No active subscription to unsubscribe');
      return true;
    }

    try {
      // Unsubscribe from push manager
      await this.pushSubscription.unsubscribe();

      // Remove from server
      if (authToken) {
        await this.removeSubscriptionFromServer(authToken);
      }

      this.pushSubscription = null;
      this.onSubscriptionChange(null);
      this.trackEvent('push_unsubscribed', {});

      return true;
    } catch (error) {
      console.error('Failed to unsubscribe:', error);
      throw error;
    }
  }

  async sendSubscriptionToServer(subscription, authToken) {
    const response = await fetch(`${this.apiBaseUrl}/api/notifications/subscribe`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${authToken}`
      },
      body: JSON.stringify({
        subscription: subscription.toJSON(),
        userAgent: navigator.userAgent,
        platform: this.getPlatform()
      })
    });

    if (!response.ok) {
      throw new Error('Failed to save subscription on server');
    }

    return response.json();
  }

  async removeSubscriptionFromServer(authToken) {
    const response = await fetch(`${this.apiBaseUrl}/api/notifications/unsubscribe`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${authToken}`
      }
    });

    if (!response.ok) {
      throw new Error('Failed to remove subscription from server');
    }

    return response.json();
  }

  isSubscribed() {
    return this.pushSubscription !== null;
  }

  getSubscription() {
    return this.pushSubscription;
  }

  // ============================================
  // LOCAL NOTIFICATIONS
  // ============================================

  async showLocalNotification(title, options = {}) {
    if (!this.isLocalNotificationSupported()) {
      console.warn('Local notifications not supported');
      return null;
    }

    if (this.getPermissionStatus() !== 'granted') {
      console.warn('Notification permission not granted');
      return null;
    }

    // Check preferences
    if (!this.preferences.enabled) {
      this.log('Notifications disabled in preferences');
      return null;
    }

    const defaultOptions = {
      icon: '/icons/icon-192.png',
      badge: '/icons/badge-72.png',
      tag: 'local-notification',
      requireInteraction: false,
      silent: !this.preferences.sound,
      vibrate: this.preferences.vibrate ? [200, 100, 200] : undefined,
      data: { type: 'local' }
    };

    const mergedOptions = { ...defaultOptions, ...options };

    try {
      if (this.serviceWorkerRegistration) {
        // Show via service worker (preferred)
        await this.serviceWorkerRegistration.showNotification(title, mergedOptions);
        this.trackEvent('local_notification_shown', { title, tag: mergedOptions.tag });
        return true;
      } else {
        // Fallback to Notification API
        const notification = new Notification(title, mergedOptions);
        this.trackEvent('local_notification_shown', { title, tag: mergedOptions.tag });
        return notification;
      }
    } catch (error) {
      console.error('Failed to show notification:', error);
      return null;
    }
  }

  // ============================================
  // RICH NOTIFICATIONS
  // ============================================

  async showRichNotification(title, body, options = {}) {
    const richOptions = {
      body,
      icon: options.icon || '/icons/icon-192.png',
      badge: options.badge || '/icons/badge-72.png',
      image: options.image,
      tag: options.tag || 'rich-notification',
      actions: options.actions || [],
      data: options.data || {},
      requireInteraction: options.requireInteraction || false
    };

    return this.showLocalNotification(title, richOptions);
  }

  async showMessageNotification(senderName, message, conversationId, options = {}) {
    // Check message notification preference
    if (!this.preferences.messageNotifications) {
      return null;
    }

    return this.showRichNotification(
      senderName,
      message,
      {
        tag: `message-${conversationId}`,
        icon: options.avatar || '/icons/icon-192.png',
        image: options.image,
        actions: [
          { action: 'reply', title: 'Reply' },
          { action: 'dismiss', title: 'Dismiss' }
        ],
        data: {
          type: 'message',
          conversationId,
          deepLink: `/?conversation=${conversationId}`,
          ...options.data
        },
        requireInteraction: true
      }
    );
  }

  async showReminderNotification(title, body, reminderId, options = {}) {
    // Check reminder notification preference
    if (!this.preferences.reminderNotifications) {
      return null;
    }

    return this.showRichNotification(
      title,
      body,
      {
        tag: `reminder-${reminderId}`,
        icon: '/icons/reminder-icon.png',
        actions: [
          { action: 'view', title: 'View' },
          { action: 'snooze', title: 'Snooze' },
          { action: 'dismiss', title: 'Dismiss' }
        ],
        data: {
          type: 'reminder',
          reminderId,
          ...options.data
        },
        requireInteraction: true
      }
    );
  }

  async showPromoNotification(title, body, options = {}) {
    // Check promo notification preference
    if (!this.preferences.promoNotifications) {
      return null;
    }

    return this.showRichNotification(
      title,
      body,
      {
        tag: 'promo',
        image: options.image,
        actions: [
          { action: 'view', title: 'Learn More' },
          { action: 'dismiss', title: 'Not Now' }
        ],
        data: {
          type: 'promo',
          url: options.url,
          ...options.data
        }
      }
    );
  }

  // ============================================
  // LOCAL REMINDERS
  // ============================================

  async scheduleReminder(id, title, body, scheduledTime, options = {}) {
    const reminder = {
      id,
      title,
      body,
      scheduledTime: new Date(scheduledTime).getTime(),
      options,
      created: Date.now()
    };

    // Store in localStorage
    const reminders = this.getStoredReminders();
    reminders[id] = reminder;
    localStorage.setItem('justlayme-reminders', JSON.stringify(reminders));

    this.log('Reminder scheduled:', reminder);
    this.trackEvent('reminder_scheduled', { id, scheduledTime: reminder.scheduledTime });

    // Set up timer if in current session
    this.setupReminderTimer(reminder);

    return reminder;
  }

  cancelReminder(id) {
    const reminders = this.getStoredReminders();

    if (reminders[id]) {
      delete reminders[id];
      localStorage.setItem('justlayme-reminders', JSON.stringify(reminders));
      this.trackEvent('reminder_cancelled', { id });
      return true;
    }

    return false;
  }

  getStoredReminders() {
    try {
      return JSON.parse(localStorage.getItem('justlayme-reminders')) || {};
    } catch {
      return {};
    }
  }

  setupReminderTimer(reminder) {
    const now = Date.now();
    const delay = reminder.scheduledTime - now;

    if (delay <= 0) {
      // Past due, show immediately
      this.showReminderNotification(reminder.title, reminder.body, reminder.id, reminder.options);
      this.cancelReminder(reminder.id);
      return;
    }

    // Max setTimeout delay is ~24.8 days
    const maxDelay = 2147483647;

    if (delay <= maxDelay) {
      setTimeout(() => {
        this.showReminderNotification(reminder.title, reminder.body, reminder.id, reminder.options);
        this.cancelReminder(reminder.id);
      }, delay);
    }
  }

  checkPendingReminders() {
    const reminders = this.getStoredReminders();
    const now = Date.now();

    for (const [id, reminder] of Object.entries(reminders)) {
      if (reminder.scheduledTime <= now) {
        // Show overdue reminder
        this.showReminderNotification(reminder.title, reminder.body, id, reminder.options);
        this.cancelReminder(id);
      } else {
        // Set up timer for future reminder
        this.setupReminderTimer(reminder);
      }
    }
  }

  // ============================================
  // NOTIFICATION PREFERENCES
  // ============================================

  loadPreferences() {
    const defaults = {
      enabled: true,
      sound: true,
      vibrate: true,
      messageNotifications: true,
      reminderNotifications: true,
      promoNotifications: true,
      quietHoursEnabled: false,
      quietHoursStart: '22:00',
      quietHoursEnd: '08:00',
      groupNotifications: true
    };

    try {
      const stored = JSON.parse(localStorage.getItem('justlayme-notification-preferences'));
      return { ...defaults, ...stored };
    } catch {
      return defaults;
    }
  }

  savePreferences(preferences) {
    this.preferences = { ...this.preferences, ...preferences };
    localStorage.setItem('justlayme-notification-preferences', JSON.stringify(this.preferences));

    // Sync to server if auth token is available
    this.syncPreferencesToServer();

    // Register background sync
    if (this.isBackgroundSyncSupported()) {
      this.serviceWorkerRegistration.sync.register('sync-preferences');
    }

    this.trackEvent('preferences_updated', preferences);

    return this.preferences;
  }

  getPreferences() {
    return { ...this.preferences };
  }

  async syncPreferencesToServer(authToken = null) {
    if (!authToken) {
      authToken = localStorage.getItem('justlayme-auth-token');
    }

    if (!authToken) {
      this.log('No auth token, skipping preferences sync');
      return;
    }

    try {
      await fetch(`${this.apiBaseUrl}/api/notifications/preferences`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${authToken}`
        },
        body: JSON.stringify(this.preferences)
      });

      this.log('Preferences synced to server');
    } catch (error) {
      console.error('Failed to sync preferences:', error);
    }
  }

  isQuietHours() {
    if (!this.preferences.quietHoursEnabled) return false;

    const now = new Date();
    const currentTime = now.getHours() * 60 + now.getMinutes();

    const [startHour, startMin] = this.preferences.quietHoursStart.split(':').map(Number);
    const [endHour, endMin] = this.preferences.quietHoursEnd.split(':').map(Number);

    const startTime = startHour * 60 + startMin;
    const endTime = endHour * 60 + endMin;

    if (startTime <= endTime) {
      return currentTime >= startTime && currentTime < endTime;
    } else {
      // Overnight quiet hours (e.g., 22:00 - 08:00)
      return currentTime >= startTime || currentTime < endTime;
    }
  }

  // ============================================
  // BACKGROUND SYNC
  // ============================================

  async registerBackgroundSync(tag) {
    if (!this.isBackgroundSyncSupported()) {
      console.warn('Background sync not supported');
      return false;
    }

    try {
      await this.serviceWorkerRegistration.sync.register(tag);
      this.log('Background sync registered:', tag);
      return true;
    } catch (error) {
      console.error('Failed to register background sync:', error);
      return false;
    }
  }

  async registerPeriodicSync(tag, minInterval = 12 * 60 * 60 * 1000) { // 12 hours default
    if (!this.isPeriodicSyncSupported()) {
      console.warn('Periodic sync not supported');
      return false;
    }

    try {
      const status = await navigator.permissions.query({
        name: 'periodic-background-sync'
      });

      if (status.state === 'granted') {
        await this.serviceWorkerRegistration.periodicSync.register(tag, {
          minInterval: minInterval
        });

        this.log('Periodic sync registered:', tag);
        return true;
      } else {
        console.warn('Periodic sync permission not granted');
        return false;
      }
    } catch (error) {
      console.error('Failed to register periodic sync:', error);
      return false;
    }
  }

  // ============================================
  // BACKGROUND FETCH
  // ============================================

  async startBackgroundFetch(id, urls, options = {}) {
    if (!this.isBackgroundFetchSupported()) {
      console.warn('Background fetch not supported');
      return null;
    }

    try {
      const bgFetch = await this.serviceWorkerRegistration.backgroundFetch.fetch(
        id,
        urls,
        {
          title: options.title || 'Downloading content...',
          icons: options.icons || [{ src: '/icons/icon-192.png', sizes: '192x192' }],
          downloadTotal: options.downloadTotal
        }
      );

      this.log('Background fetch started:', id);
      return bgFetch;
    } catch (error) {
      console.error('Failed to start background fetch:', error);
      return null;
    }
  }

  async getBackgroundFetch(id) {
    if (!this.isBackgroundFetchSupported()) return null;

    return this.serviceWorkerRegistration.backgroundFetch.get(id);
  }

  // ============================================
  // SERVICE WORKER COMMUNICATION
  // ============================================

  handleServiceWorkerMessage(event) {
    const { type, data } = event.data;

    this.log('Received message from service worker:', type, data);

    switch (type) {
      case 'MESSAGES_SYNCED':
        this.onNotificationReceived({ type: 'sync', data });
        break;

      case 'PENDING_MESSAGE_SENT':
        this.onNotificationReceived({ type: 'pending_sent', messageId: data?.messageId });
        break;

      case 'SILENT_PUSH_HANDLED':
        this.onNotificationReceived({ type: 'silent_push', action: data?.action });
        break;

      default:
        this.log('Unknown message type:', type);
    }
  }

  postMessageToSW(message) {
    if (navigator.serviceWorker.controller) {
      navigator.serviceWorker.controller.postMessage(message);
    }
  }

  storeAuthToken(token) {
    localStorage.setItem('justlayme-auth-token', token);
    this.postMessageToSW({ type: 'STORE_TOKEN', data: { token } });
  }

  storePendingMessage(message) {
    this.postMessageToSW({ type: 'STORE_PENDING_MESSAGE', data: message });
  }

  // ============================================
  // BADGE MANAGEMENT
  // ============================================

  async setBadge(count) {
    if ('setAppBadge' in navigator) {
      try {
        if (count > 0) {
          await navigator.setAppBadge(count);
        } else {
          await navigator.clearAppBadge();
        }
        this.log('Badge set to:', count);
        return true;
      } catch (error) {
        console.error('Failed to set badge:', error);
        return false;
      }
    }
    return false;
  }

  async clearBadge() {
    return this.setBadge(0);
  }

  // ============================================
  // ANALYTICS
  // ============================================

  trackEvent(eventName, eventData = {}) {
    const event = {
      id: `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
      name: eventName,
      data: eventData,
      timestamp: Date.now(),
      sessionId: this.getSessionId()
    };

    this.analyticsQueue.push(event);
    this.log('Analytics event tracked:', event);

    // Try to send immediately if queue is large
    if (this.analyticsQueue.length >= 10) {
      this.flushAnalytics();
    }
  }

  startAnalyticsFlush() {
    // Flush analytics every 30 seconds
    this.analyticsFlushInterval = setInterval(() => {
      this.flushAnalytics();
    }, 30000);
  }

  stopAnalyticsFlush() {
    if (this.analyticsFlushInterval) {
      clearInterval(this.analyticsFlushInterval);
      this.analyticsFlushInterval = null;
    }
  }

  async flushAnalytics() {
    if (this.analyticsQueue.length === 0) return;

    const authToken = localStorage.getItem('justlayme-auth-token');
    const events = [...this.analyticsQueue];
    this.analyticsQueue = [];

    try {
      const response = await fetch(`${this.apiBaseUrl}/api/notifications/analytics/batch`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          ...(authToken ? { 'Authorization': `Bearer ${authToken}` } : {})
        },
        body: JSON.stringify({ events })
      });

      if (!response.ok) {
        // Put events back in queue
        this.analyticsQueue.unshift(...events);
      } else {
        this.log('Analytics flushed:', events.length, 'events');
      }
    } catch (error) {
      // Put events back in queue
      this.analyticsQueue.unshift(...events);
      console.error('Failed to flush analytics:', error);
    }
  }

  // ============================================
  // UTILITY METHODS
  // ============================================

  urlBase64ToUint8Array(base64String) {
    const padding = '='.repeat((4 - base64String.length % 4) % 4);
    const base64 = (base64String + padding)
      .replace(/-/g, '+')
      .replace(/_/g, '/');

    const rawData = window.atob(base64);
    const outputArray = new Uint8Array(rawData.length);

    for (let i = 0; i < rawData.length; ++i) {
      outputArray[i] = rawData.charCodeAt(i);
    }

    return outputArray;
  }

  getPlatform() {
    const userAgent = navigator.userAgent;

    if (/Android/i.test(userAgent)) return 'android';
    if (/iPhone|iPad|iPod/i.test(userAgent)) return 'ios';
    if (/Windows/i.test(userAgent)) return 'windows';
    if (/Mac/i.test(userAgent)) return 'macos';
    if (/Linux/i.test(userAgent)) return 'linux';

    return 'unknown';
  }

  getSessionId() {
    let sessionId = sessionStorage.getItem('justlayme-notification-session');

    if (!sessionId) {
      sessionId = `ns-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
      sessionStorage.setItem('justlayme-notification-session', sessionId);
    }

    return sessionId;
  }

  log(...args) {
    if (this.debug) {
      console.log('[NotificationService]', ...args);
    }
  }

  // ============================================
  // CLEANUP
  // ============================================

  destroy() {
    this.stopAnalyticsFlush();

    if (navigator.serviceWorker) {
      navigator.serviceWorker.removeEventListener('message', this.handleServiceWorkerMessage);
    }

    this.isInitialized = false;
  }
}

// ============================================
// NOTIFICATION PREFERENCES UI COMPONENT
// ============================================

class NotificationPreferencesUI {
  constructor(notificationService, containerSelector) {
    this.service = notificationService;
    this.container = document.querySelector(containerSelector);
    this.preferences = this.service.getPreferences();
  }

  render() {
    if (!this.container) {
      console.error('Container not found for notification preferences UI');
      return;
    }

    const permissionStatus = this.service.getPermissionStatus();
    const isSubscribed = this.service.isSubscribed();

    this.container.innerHTML = `
      <div class="notification-preferences">
        <h3>Notification Settings</h3>

        <!-- Permission Status -->
        <div class="preference-section">
          <div class="preference-status ${permissionStatus}">
            <span class="status-icon">${this.getStatusIcon(permissionStatus)}</span>
            <span class="status-text">${this.getStatusText(permissionStatus)}</span>
          </div>

          ${permissionStatus === 'default' ? `
            <button id="enable-notifications-btn" class="primary-btn">
              Enable Notifications
            </button>
          ` : ''}

          ${permissionStatus === 'denied' ? `
            <p class="help-text">
              Notifications are blocked. Please enable them in your browser settings.
            </p>
          ` : ''}
        </div>

        ${permissionStatus === 'granted' ? `
          <!-- Push Subscription -->
          <div class="preference-section">
            <h4>Push Notifications</h4>
            <label class="preference-toggle">
              <input type="checkbox" id="push-enabled" ${isSubscribed ? 'checked' : ''}>
              <span class="toggle-slider"></span>
              <span class="toggle-label">Receive push notifications</span>
            </label>
          </div>

          <!-- General Settings -->
          <div class="preference-section">
            <h4>General</h4>

            <label class="preference-toggle">
              <input type="checkbox" id="pref-enabled" ${this.preferences.enabled ? 'checked' : ''}>
              <span class="toggle-slider"></span>
              <span class="toggle-label">Enable all notifications</span>
            </label>

            <label class="preference-toggle">
              <input type="checkbox" id="pref-sound" ${this.preferences.sound ? 'checked' : ''}>
              <span class="toggle-slider"></span>
              <span class="toggle-label">Notification sounds</span>
            </label>

            <label class="preference-toggle">
              <input type="checkbox" id="pref-vibrate" ${this.preferences.vibrate ? 'checked' : ''}>
              <span class="toggle-slider"></span>
              <span class="toggle-label">Vibration</span>
            </label>
          </div>

          <!-- Notification Types -->
          <div class="preference-section">
            <h4>Notification Types</h4>

            <label class="preference-toggle">
              <input type="checkbox" id="pref-messages" ${this.preferences.messageNotifications ? 'checked' : ''}>
              <span class="toggle-slider"></span>
              <span class="toggle-label">Message notifications</span>
            </label>

            <label class="preference-toggle">
              <input type="checkbox" id="pref-reminders" ${this.preferences.reminderNotifications ? 'checked' : ''}>
              <span class="toggle-slider"></span>
              <span class="toggle-label">Reminder notifications</span>
            </label>

            <label class="preference-toggle">
              <input type="checkbox" id="pref-promos" ${this.preferences.promoNotifications ? 'checked' : ''}>
              <span class="toggle-slider"></span>
              <span class="toggle-label">Promotional notifications</span>
            </label>
          </div>

          <!-- Quiet Hours -->
          <div class="preference-section">
            <h4>Quiet Hours</h4>

            <label class="preference-toggle">
              <input type="checkbox" id="pref-quiet-enabled" ${this.preferences.quietHoursEnabled ? 'checked' : ''}>
              <span class="toggle-slider"></span>
              <span class="toggle-label">Enable quiet hours</span>
            </label>

            <div class="quiet-hours-times ${this.preferences.quietHoursEnabled ? '' : 'disabled'}">
              <div class="time-input">
                <label for="quiet-start">From</label>
                <input type="time" id="quiet-start" value="${this.preferences.quietHoursStart}">
              </div>
              <div class="time-input">
                <label for="quiet-end">To</label>
                <input type="time" id="quiet-end" value="${this.preferences.quietHoursEnd}">
              </div>
            </div>
          </div>

          <!-- Test Notification -->
          <div class="preference-section">
            <button id="test-notification-btn" class="secondary-btn">
              Send Test Notification
            </button>
          </div>
        ` : ''}
      </div>
    `;

    this.attachEventListeners();
  }

  attachEventListeners() {
    // Enable notifications button
    const enableBtn = document.getElementById('enable-notifications-btn');
    if (enableBtn) {
      enableBtn.addEventListener('click', async () => {
        const permission = await this.service.requestPermission();
        if (permission === 'granted') {
          await this.service.subscribe(localStorage.getItem('justlayme-auth-token'));
        }
        this.render();
      });
    }

    // Push subscription toggle
    const pushEnabled = document.getElementById('push-enabled');
    if (pushEnabled) {
      pushEnabled.addEventListener('change', async (e) => {
        const authToken = localStorage.getItem('justlayme-auth-token');
        if (e.target.checked) {
          await this.service.subscribe(authToken);
        } else {
          await this.service.unsubscribe(authToken);
        }
      });
    }

    // Preference toggles
    const prefMappings = [
      ['pref-enabled', 'enabled'],
      ['pref-sound', 'sound'],
      ['pref-vibrate', 'vibrate'],
      ['pref-messages', 'messageNotifications'],
      ['pref-reminders', 'reminderNotifications'],
      ['pref-promos', 'promoNotifications'],
      ['pref-quiet-enabled', 'quietHoursEnabled']
    ];

    prefMappings.forEach(([id, key]) => {
      const el = document.getElementById(id);
      if (el) {
        el.addEventListener('change', (e) => {
          this.preferences[key] = e.target.checked;
          this.service.savePreferences(this.preferences);

          // Toggle quiet hours inputs
          if (key === 'quietHoursEnabled') {
            const quietTimes = document.querySelector('.quiet-hours-times');
            if (quietTimes) {
              quietTimes.classList.toggle('disabled', !e.target.checked);
            }
          }
        });
      }
    });

    // Quiet hours times
    const quietStart = document.getElementById('quiet-start');
    const quietEnd = document.getElementById('quiet-end');

    if (quietStart) {
      quietStart.addEventListener('change', (e) => {
        this.preferences.quietHoursStart = e.target.value;
        this.service.savePreferences(this.preferences);
      });
    }

    if (quietEnd) {
      quietEnd.addEventListener('change', (e) => {
        this.preferences.quietHoursEnd = e.target.value;
        this.service.savePreferences(this.preferences);
      });
    }

    // Test notification button
    const testBtn = document.getElementById('test-notification-btn');
    if (testBtn) {
      testBtn.addEventListener('click', () => {
        this.service.showLocalNotification('Test Notification', {
          body: 'This is a test notification from JustLayMe!',
          icon: '/icons/icon-192.png',
          tag: 'test'
        });
      });
    }
  }

  getStatusIcon(status) {
    switch (status) {
      case 'granted': return '&#10003;';
      case 'denied': return '&#10007;';
      default: return '&#8227;';
    }
  }

  getStatusText(status) {
    switch (status) {
      case 'granted': return 'Notifications are enabled';
      case 'denied': return 'Notifications are blocked';
      case 'unsupported': return 'Notifications not supported';
      default: return 'Notifications are not yet enabled';
    }
  }
}

// Export for use in modules or global
if (typeof module !== 'undefined' && module.exports) {
  module.exports = { NotificationService, NotificationPreferencesUI };
} else {
  window.NotificationService = NotificationService;
  window.NotificationPreferencesUI = NotificationPreferencesUI;
}
