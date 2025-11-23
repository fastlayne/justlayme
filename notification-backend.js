/**
 * JustLayMe Push Notification Backend Service
 * Handles VAPID keys, subscriptions, sending notifications, and analytics
 * @version 1.0.0
 */

const webpush = require('web-push');
const crypto = require('crypto');

class NotificationBackend {
  constructor(db, options = {}) {
    this.db = db;
    this.debug = options.debug || false;

    // VAPID keys - generate once and store in environment
    this.vapidKeys = {
      publicKey: process.env.VAPID_PUBLIC_KEY || null,
      privateKey: process.env.VAPID_PRIVATE_KEY || null,
      subject: process.env.VAPID_SUBJECT || 'mailto:support@justlay.me'
    };

    // Generate keys if not provided
    if (!this.vapidKeys.publicKey || !this.vapidKeys.privateKey) {
      this.generateVapidKeys();
    }

    // Configure web-push
    webpush.setVapidDetails(
      this.vapidKeys.subject,
      this.vapidKeys.publicKey,
      this.vapidKeys.privateKey
    );

    this.log('Notification backend initialized');
  }

  // ============================================
  // VAPID KEY MANAGEMENT
  // ============================================

  generateVapidKeys() {
    const keys = webpush.generateVAPIDKeys();
    this.vapidKeys.publicKey = keys.publicKey;
    this.vapidKeys.privateKey = keys.privateKey;

    console.log('='.repeat(60));
    console.log('VAPID KEYS GENERATED - Add these to your environment:');
    console.log('='.repeat(60));
    console.log(`VAPID_PUBLIC_KEY=${keys.publicKey}`);
    console.log(`VAPID_PRIVATE_KEY=${keys.privateKey}`);
    console.log('='.repeat(60));

    webpush.setVapidDetails(
      this.vapidKeys.subject,
      this.vapidKeys.publicKey,
      this.vapidKeys.privateKey
    );
  }

  getPublicKey() {
    return this.vapidKeys.publicKey;
  }

  // ============================================
  // DATABASE INITIALIZATION
  // ============================================

  async initDatabase() {
    this.log('Initializing notification database tables...');

    try {
      // Push subscriptions table
      await this.db.query(`
        CREATE TABLE IF NOT EXISTS push_subscriptions (
          id ${this.db.usePostgres ? 'UUID PRIMARY KEY DEFAULT gen_random_uuid()' : 'TEXT PRIMARY KEY'},
          user_id TEXT NOT NULL,
          endpoint TEXT NOT NULL UNIQUE,
          p256dh TEXT NOT NULL,
          auth TEXT NOT NULL,
          user_agent TEXT,
          platform TEXT,
          created_at ${this.db.usePostgres ? 'TIMESTAMP DEFAULT NOW()' : 'TEXT DEFAULT CURRENT_TIMESTAMP'},
          last_used ${this.db.usePostgres ? 'TIMESTAMP DEFAULT NOW()' : 'TEXT DEFAULT CURRENT_TIMESTAMP'}
        )
      `);

      // Notification preferences table
      await this.db.query(`
        CREATE TABLE IF NOT EXISTS notification_preferences (
          id ${this.db.usePostgres ? 'UUID PRIMARY KEY DEFAULT gen_random_uuid()' : 'TEXT PRIMARY KEY'},
          user_id TEXT UNIQUE NOT NULL,
          enabled ${this.db.usePostgres ? 'BOOLEAN DEFAULT true' : 'INTEGER DEFAULT 1'},
          sound ${this.db.usePostgres ? 'BOOLEAN DEFAULT true' : 'INTEGER DEFAULT 1'},
          vibrate ${this.db.usePostgres ? 'BOOLEAN DEFAULT true' : 'INTEGER DEFAULT 1'},
          message_notifications ${this.db.usePostgres ? 'BOOLEAN DEFAULT true' : 'INTEGER DEFAULT 1'},
          reminder_notifications ${this.db.usePostgres ? 'BOOLEAN DEFAULT true' : 'INTEGER DEFAULT 1'},
          promo_notifications ${this.db.usePostgres ? 'BOOLEAN DEFAULT true' : 'INTEGER DEFAULT 1'},
          quiet_hours_enabled ${this.db.usePostgres ? 'BOOLEAN DEFAULT false' : 'INTEGER DEFAULT 0'},
          quiet_hours_start TEXT DEFAULT '22:00',
          quiet_hours_end TEXT DEFAULT '08:00',
          updated_at ${this.db.usePostgres ? 'TIMESTAMP DEFAULT NOW()' : 'TEXT DEFAULT CURRENT_TIMESTAMP'}
        )
      `);

      // Notification history table
      await this.db.query(`
        CREATE TABLE IF NOT EXISTS notification_history (
          id ${this.db.usePostgres ? 'UUID PRIMARY KEY DEFAULT gen_random_uuid()' : 'TEXT PRIMARY KEY'},
          user_id TEXT,
          type TEXT NOT NULL,
          title TEXT NOT NULL,
          body TEXT,
          data ${this.db.usePostgres ? 'JSONB' : 'TEXT'},
          sent_at ${this.db.usePostgres ? 'TIMESTAMP DEFAULT NOW()' : 'TEXT DEFAULT CURRENT_TIMESTAMP'},
          delivered ${this.db.usePostgres ? 'BOOLEAN DEFAULT false' : 'INTEGER DEFAULT 0'},
          clicked ${this.db.usePostgres ? 'BOOLEAN DEFAULT false' : 'INTEGER DEFAULT 0'},
          dismissed ${this.db.usePostgres ? 'BOOLEAN DEFAULT false' : 'INTEGER DEFAULT 0'}
        )
      `);

      // Notification analytics table
      await this.db.query(`
        CREATE TABLE IF NOT EXISTS notification_analytics (
          id ${this.db.usePostgres ? 'UUID PRIMARY KEY DEFAULT gen_random_uuid()' : 'TEXT PRIMARY KEY'},
          user_id TEXT,
          session_id TEXT,
          event_name TEXT NOT NULL,
          event_data ${this.db.usePostgres ? 'JSONB' : 'TEXT'},
          timestamp ${this.db.usePostgres ? 'TIMESTAMP DEFAULT NOW()' : 'TEXT DEFAULT CURRENT_TIMESTAMP'}
        )
      `);

      // Scheduled notifications table
      await this.db.query(`
        CREATE TABLE IF NOT EXISTS scheduled_notifications (
          id ${this.db.usePostgres ? 'UUID PRIMARY KEY DEFAULT gen_random_uuid()' : 'TEXT PRIMARY KEY'},
          user_id TEXT,
          type TEXT NOT NULL,
          title TEXT NOT NULL,
          body TEXT,
          data ${this.db.usePostgres ? 'JSONB' : 'TEXT'},
          scheduled_for ${this.db.usePostgres ? 'TIMESTAMP NOT NULL' : 'TEXT NOT NULL'},
          sent ${this.db.usePostgres ? 'BOOLEAN DEFAULT false' : 'INTEGER DEFAULT 0'},
          created_at ${this.db.usePostgres ? 'TIMESTAMP DEFAULT NOW()' : 'TEXT DEFAULT CURRENT_TIMESTAMP'}
        )
      `);

      // Create indexes
      if (this.db.usePostgres) {
        await this.db.query(`
          CREATE INDEX IF NOT EXISTS idx_push_subscriptions_user ON push_subscriptions(user_id);
          CREATE INDEX IF NOT EXISTS idx_notification_history_user ON notification_history(user_id);
          CREATE INDEX IF NOT EXISTS idx_notification_analytics_user ON notification_analytics(user_id);
          CREATE INDEX IF NOT EXISTS idx_scheduled_notifications_time ON scheduled_notifications(scheduled_for);
        `);
      }

      this.log('Notification database tables initialized');
      return true;
    } catch (error) {
      console.error('Error initializing notification database:', error);
      return false;
    }
  }

  // ============================================
  // SUBSCRIPTION MANAGEMENT
  // ============================================

  async saveSubscription(userId, subscription, metadata = {}) {
    this.log('Saving subscription for user:', userId);

    try {
      const { endpoint, keys } = subscription;
      const { p256dh, auth } = keys;
      const id = this.generateId();

      // Check if subscription already exists
      const existing = await this.db.query(
        'SELECT id FROM push_subscriptions WHERE endpoint = $1',
        [endpoint]
      );

      if (existing.rows.length > 0) {
        // Update existing subscription
        await this.db.query(`
          UPDATE push_subscriptions
          SET user_id = $1, p256dh = $2, auth = $3, user_agent = $4, platform = $5, last_used = ${this.db.usePostgres ? 'NOW()' : 'CURRENT_TIMESTAMP'}
          WHERE endpoint = $6
        `, [userId, p256dh, auth, metadata.userAgent, metadata.platform, endpoint]);

        return { id: existing.rows[0].id, updated: true };
      }

      // Insert new subscription
      await this.db.query(`
        INSERT INTO push_subscriptions (id, user_id, endpoint, p256dh, auth, user_agent, platform)
        VALUES ($1, $2, $3, $4, $5, $6, $7)
      `, [id, userId, endpoint, p256dh, auth, metadata.userAgent, metadata.platform]);

      return { id, updated: false };
    } catch (error) {
      console.error('Error saving subscription:', error);
      throw error;
    }
  }

  async removeSubscription(userId, endpoint = null) {
    this.log('Removing subscription for user:', userId);

    try {
      if (endpoint) {
        await this.db.query(
          'DELETE FROM push_subscriptions WHERE user_id = $1 AND endpoint = $2',
          [userId, endpoint]
        );
      } else {
        // Remove all subscriptions for user
        await this.db.query(
          'DELETE FROM push_subscriptions WHERE user_id = $1',
          [userId]
        );
      }

      return true;
    } catch (error) {
      console.error('Error removing subscription:', error);
      throw error;
    }
  }

  async getUserSubscriptions(userId) {
    try {
      const result = await this.db.query(
        'SELECT * FROM push_subscriptions WHERE user_id = $1',
        [userId]
      );

      return result.rows.map(row => ({
        endpoint: row.endpoint,
        keys: {
          p256dh: row.p256dh,
          auth: row.auth
        }
      }));
    } catch (error) {
      console.error('Error getting user subscriptions:', error);
      return [];
    }
  }

  async getAllSubscriptions() {
    try {
      const result = await this.db.query('SELECT * FROM push_subscriptions');

      return result.rows.map(row => ({
        userId: row.user_id,
        subscription: {
          endpoint: row.endpoint,
          keys: {
            p256dh: row.p256dh,
            auth: row.auth
          }
        }
      }));
    } catch (error) {
      console.error('Error getting all subscriptions:', error);
      return [];
    }
  }

  // ============================================
  // SENDING NOTIFICATIONS
  // ============================================

  async sendNotification(userId, notification, options = {}) {
    this.log('Sending notification to user:', userId);

    try {
      // Check user preferences
      const preferences = await this.getPreferences(userId);

      if (!preferences.enabled) {
        this.log('Notifications disabled for user:', userId);
        return { sent: false, reason: 'disabled' };
      }

      // Check quiet hours
      if (this.isQuietHours(preferences) && !options.ignoreQuietHours) {
        this.log('Quiet hours active for user:', userId);
        return { sent: false, reason: 'quiet_hours' };
      }

      // Check notification type preferences
      if (notification.type === 'message' && !preferences.message_notifications) {
        return { sent: false, reason: 'message_notifications_disabled' };
      }
      if (notification.type === 'reminder' && !preferences.reminder_notifications) {
        return { sent: false, reason: 'reminder_notifications_disabled' };
      }
      if (notification.type === 'promo' && !preferences.promo_notifications) {
        return { sent: false, reason: 'promo_notifications_disabled' };
      }

      // Get user subscriptions
      const subscriptions = await this.getUserSubscriptions(userId);

      if (subscriptions.length === 0) {
        return { sent: false, reason: 'no_subscriptions' };
      }

      // Prepare notification payload
      const payload = JSON.stringify({
        title: notification.title,
        body: notification.body,
        icon: notification.icon || '/icons/icon-192.png',
        badge: notification.badge || '/icons/badge-72.png',
        image: notification.image,
        tag: notification.tag || notification.type || 'default',
        data: {
          type: notification.type,
          url: notification.url,
          deepLink: notification.deepLink,
          conversationId: notification.conversationId,
          characterId: notification.characterId,
          ...notification.data
        },
        actions: notification.actions || [],
        requireInteraction: notification.requireInteraction || false,
        silent: !preferences.sound,
        vibrate: preferences.vibrate ? [200, 100, 200] : undefined,
        renotify: notification.renotify || false
      });

      // Send to all user devices
      const results = await Promise.allSettled(
        subscriptions.map(subscription =>
          this.sendToSubscription(subscription, payload)
        )
      );

      // Process results and clean up failed subscriptions
      let sentCount = 0;
      const failedEndpoints = [];

      for (let i = 0; i < results.length; i++) {
        if (results[i].status === 'fulfilled') {
          sentCount++;
        } else {
          const error = results[i].reason;
          if (error.statusCode === 410 || error.statusCode === 404) {
            // Subscription expired or not found
            failedEndpoints.push(subscriptions[i].endpoint);
          }
        }
      }

      // Remove failed subscriptions
      for (const endpoint of failedEndpoints) {
        await this.removeSubscription(userId, endpoint);
      }

      // Record in history
      await this.recordNotification(userId, notification, sentCount > 0);

      return {
        sent: sentCount > 0,
        sentCount,
        totalDevices: subscriptions.length,
        failedCount: subscriptions.length - sentCount
      };
    } catch (error) {
      console.error('Error sending notification:', error);
      throw error;
    }
  }

  async sendToSubscription(subscription, payload) {
    return webpush.sendNotification(subscription, payload, {
      TTL: 86400, // 24 hours
      urgency: 'normal'
    });
  }

  async sendToAll(notification, options = {}) {
    this.log('Sending notification to all users');

    try {
      const allSubscriptions = await this.getAllSubscriptions();
      const userIds = [...new Set(allSubscriptions.map(s => s.userId))];

      const results = await Promise.allSettled(
        userIds.map(userId => this.sendNotification(userId, notification, options))
      );

      let totalSent = 0;
      let totalFailed = 0;

      results.forEach(result => {
        if (result.status === 'fulfilled' && result.value.sent) {
          totalSent += result.value.sentCount;
        } else {
          totalFailed++;
        }
      });

      return { totalSent, totalFailed, totalUsers: userIds.length };
    } catch (error) {
      console.error('Error sending to all:', error);
      throw error;
    }
  }

  async sendSilentPush(userId, data) {
    this.log('Sending silent push to user:', userId);

    const payload = JSON.stringify({
      silent: true,
      type: 'background-update',
      action: data.action,
      ...data
    });

    const subscriptions = await this.getUserSubscriptions(userId);

    const results = await Promise.allSettled(
      subscriptions.map(subscription =>
        this.sendToSubscription(subscription, payload)
      )
    );

    return {
      sent: results.filter(r => r.status === 'fulfilled').length,
      total: subscriptions.length
    };
  }

  // ============================================
  // SCHEDULED NOTIFICATIONS
  // ============================================

  async scheduleNotification(userId, notification, scheduledFor) {
    this.log('Scheduling notification for user:', userId, 'at:', scheduledFor);

    try {
      const id = this.generateId();
      const data = JSON.stringify(notification.data || {});

      await this.db.query(`
        INSERT INTO scheduled_notifications (id, user_id, type, title, body, data, scheduled_for)
        VALUES ($1, $2, $3, $4, $5, $6, $7)
      `, [id, userId, notification.type, notification.title, notification.body, data, scheduledFor]);

      return { id, scheduledFor };
    } catch (error) {
      console.error('Error scheduling notification:', error);
      throw error;
    }
  }

  async cancelScheduledNotification(id) {
    try {
      await this.db.query('DELETE FROM scheduled_notifications WHERE id = $1', [id]);
      return true;
    } catch (error) {
      console.error('Error cancelling scheduled notification:', error);
      return false;
    }
  }

  async processScheduledNotifications() {
    this.log('Processing scheduled notifications...');

    try {
      const now = new Date().toISOString();

      const result = await this.db.query(`
        SELECT * FROM scheduled_notifications
        WHERE scheduled_for <= $1 AND sent = ${this.db.usePostgres ? 'false' : '0'}
      `, [now]);

      for (const row of result.rows) {
        try {
          const data = typeof row.data === 'string' ? JSON.parse(row.data) : row.data;

          await this.sendNotification(row.user_id, {
            type: row.type,
            title: row.title,
            body: row.body,
            data
          });

          // Mark as sent
          await this.db.query(`
            UPDATE scheduled_notifications SET sent = ${this.db.usePostgres ? 'true' : '1'} WHERE id = $1
          `, [row.id]);
        } catch (sendError) {
          console.error('Error sending scheduled notification:', row.id, sendError);
        }
      }

      return { processed: result.rows.length };
    } catch (error) {
      console.error('Error processing scheduled notifications:', error);
      return { processed: 0 };
    }
  }

  // ============================================
  // PREFERENCES MANAGEMENT
  // ============================================

  async getPreferences(userId) {
    try {
      const result = await this.db.query(
        'SELECT * FROM notification_preferences WHERE user_id = $1',
        [userId]
      );

      if (result.rows.length === 0) {
        // Return defaults
        return {
          enabled: true,
          sound: true,
          vibrate: true,
          message_notifications: true,
          reminder_notifications: true,
          promo_notifications: true,
          quiet_hours_enabled: false,
          quiet_hours_start: '22:00',
          quiet_hours_end: '08:00'
        };
      }

      const row = result.rows[0];

      // Handle SQLite boolean conversion
      return {
        enabled: Boolean(row.enabled),
        sound: Boolean(row.sound),
        vibrate: Boolean(row.vibrate),
        message_notifications: Boolean(row.message_notifications),
        reminder_notifications: Boolean(row.reminder_notifications),
        promo_notifications: Boolean(row.promo_notifications),
        quiet_hours_enabled: Boolean(row.quiet_hours_enabled),
        quiet_hours_start: row.quiet_hours_start,
        quiet_hours_end: row.quiet_hours_end
      };
    } catch (error) {
      console.error('Error getting preferences:', error);
      return {
        enabled: true,
        sound: true,
        vibrate: true,
        message_notifications: true,
        reminder_notifications: true,
        promo_notifications: true,
        quiet_hours_enabled: false,
        quiet_hours_start: '22:00',
        quiet_hours_end: '08:00'
      };
    }
  }

  async savePreferences(userId, preferences) {
    this.log('Saving preferences for user:', userId);

    try {
      const existing = await this.db.query(
        'SELECT id FROM notification_preferences WHERE user_id = $1',
        [userId]
      );

      // Convert booleans for SQLite
      const boolToInt = this.db.usePostgres ? (v) => v : (v) => v ? 1 : 0;

      if (existing.rows.length > 0) {
        await this.db.query(`
          UPDATE notification_preferences SET
            enabled = $1,
            sound = $2,
            vibrate = $3,
            message_notifications = $4,
            reminder_notifications = $5,
            promo_notifications = $6,
            quiet_hours_enabled = $7,
            quiet_hours_start = $8,
            quiet_hours_end = $9,
            updated_at = ${this.db.usePostgres ? 'NOW()' : 'CURRENT_TIMESTAMP'}
          WHERE user_id = $10
        `, [
          boolToInt(preferences.enabled),
          boolToInt(preferences.sound),
          boolToInt(preferences.vibrate),
          boolToInt(preferences.messageNotifications ?? preferences.message_notifications),
          boolToInt(preferences.reminderNotifications ?? preferences.reminder_notifications),
          boolToInt(preferences.promoNotifications ?? preferences.promo_notifications),
          boolToInt(preferences.quietHoursEnabled ?? preferences.quiet_hours_enabled),
          preferences.quietHoursStart ?? preferences.quiet_hours_start ?? '22:00',
          preferences.quietHoursEnd ?? preferences.quiet_hours_end ?? '08:00',
          userId
        ]);
      } else {
        const id = this.generateId();
        await this.db.query(`
          INSERT INTO notification_preferences (
            id, user_id, enabled, sound, vibrate, message_notifications,
            reminder_notifications, promo_notifications, quiet_hours_enabled,
            quiet_hours_start, quiet_hours_end
          )
          VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
        `, [
          id,
          userId,
          boolToInt(preferences.enabled),
          boolToInt(preferences.sound),
          boolToInt(preferences.vibrate),
          boolToInt(preferences.messageNotifications ?? preferences.message_notifications),
          boolToInt(preferences.reminderNotifications ?? preferences.reminder_notifications),
          boolToInt(preferences.promoNotifications ?? preferences.promo_notifications),
          boolToInt(preferences.quietHoursEnabled ?? preferences.quiet_hours_enabled),
          preferences.quietHoursStart ?? preferences.quiet_hours_start ?? '22:00',
          preferences.quietHoursEnd ?? preferences.quiet_hours_end ?? '08:00'
        ]);
      }

      return true;
    } catch (error) {
      console.error('Error saving preferences:', error);
      throw error;
    }
  }

  isQuietHours(preferences) {
    if (!preferences.quiet_hours_enabled) return false;

    const now = new Date();
    const currentMinutes = now.getHours() * 60 + now.getMinutes();

    const [startH, startM] = preferences.quiet_hours_start.split(':').map(Number);
    const [endH, endM] = preferences.quiet_hours_end.split(':').map(Number);

    const startMinutes = startH * 60 + startM;
    const endMinutes = endH * 60 + endM;

    if (startMinutes <= endMinutes) {
      return currentMinutes >= startMinutes && currentMinutes < endMinutes;
    } else {
      // Overnight (e.g., 22:00 - 08:00)
      return currentMinutes >= startMinutes || currentMinutes < endMinutes;
    }
  }

  // ============================================
  // NOTIFICATION HISTORY & ANALYTICS
  // ============================================

  async recordNotification(userId, notification, delivered) {
    try {
      const id = this.generateId();
      const data = JSON.stringify(notification.data || {});

      await this.db.query(`
        INSERT INTO notification_history (id, user_id, type, title, body, data, delivered)
        VALUES ($1, $2, $3, $4, $5, $6, $7)
      `, [id, userId, notification.type, notification.title, notification.body, data, delivered ? 1 : 0]);

      return id;
    } catch (error) {
      console.error('Error recording notification:', error);
    }
  }

  async recordAnalyticsEvent(event) {
    try {
      const id = event.id || this.generateId();
      const eventData = JSON.stringify(event.data || {});

      await this.db.query(`
        INSERT INTO notification_analytics (id, user_id, session_id, event_name, event_data, timestamp)
        VALUES ($1, $2, $3, $4, $5, $6)
      `, [id, event.userId, event.sessionId, event.name, eventData, new Date(event.timestamp).toISOString()]);

      return true;
    } catch (error) {
      console.error('Error recording analytics event:', error);
      return false;
    }
  }

  async recordAnalyticsBatch(events) {
    let recorded = 0;

    for (const event of events) {
      if (await this.recordAnalyticsEvent(event)) {
        recorded++;
      }
    }

    return { recorded, total: events.length };
  }

  async getNotificationStats(userId, days = 30) {
    try {
      const cutoff = new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString();

      const result = await this.db.query(`
        SELECT
          COUNT(*) as total,
          SUM(CASE WHEN delivered = ${this.db.usePostgres ? 'true' : '1'} THEN 1 ELSE 0 END) as delivered,
          SUM(CASE WHEN clicked = ${this.db.usePostgres ? 'true' : '1'} THEN 1 ELSE 0 END) as clicked,
          SUM(CASE WHEN dismissed = ${this.db.usePostgres ? 'true' : '1'} THEN 1 ELSE 0 END) as dismissed
        FROM notification_history
        WHERE user_id = $1 AND sent_at >= $2
      `, [userId, cutoff]);

      const row = result.rows[0] || { total: 0, delivered: 0, clicked: 0, dismissed: 0 };

      return {
        total: parseInt(row.total) || 0,
        delivered: parseInt(row.delivered) || 0,
        clicked: parseInt(row.clicked) || 0,
        dismissed: parseInt(row.dismissed) || 0,
        clickRate: row.delivered > 0 ? ((row.clicked / row.delivered) * 100).toFixed(2) : 0
      };
    } catch (error) {
      console.error('Error getting notification stats:', error);
      return { total: 0, delivered: 0, clicked: 0, dismissed: 0, clickRate: 0 };
    }
  }

  async getUnreadCount(userId, since = null) {
    try {
      let query = 'SELECT COUNT(*) as count FROM notification_history WHERE user_id = $1 AND clicked = 0';
      const params = [userId];

      if (since) {
        query += ' AND sent_at >= $2';
        params.push(new Date(since).toISOString());
      }

      const result = await this.db.query(query, params);

      return { count: parseInt(result.rows[0]?.count) || 0 };
    } catch (error) {
      console.error('Error getting unread count:', error);
      return { count: 0 };
    }
  }

  // ============================================
  // UTILITY METHODS
  // ============================================

  generateId() {
    return `${Date.now()}-${crypto.randomBytes(8).toString('hex')}`;
  }

  log(...args) {
    if (this.debug) {
      console.log('[NotificationBackend]', ...args);
    }
  }

  // ============================================
  // NOTIFICATION TEMPLATES
  // ============================================

  createMessageNotification(senderName, message, conversationId, options = {}) {
    return {
      type: 'message',
      title: senderName,
      body: message.length > 100 ? message.substring(0, 97) + '...' : message,
      tag: `message-${conversationId}`,
      conversationId,
      deepLink: `/?conversation=${conversationId}`,
      actions: [
        { action: 'reply', title: 'Reply' },
        { action: 'dismiss', title: 'Dismiss' }
      ],
      requireInteraction: true,
      ...options
    };
  }

  createReminderNotification(title, body, reminderId, options = {}) {
    return {
      type: 'reminder',
      title,
      body,
      tag: `reminder-${reminderId}`,
      data: { reminderId },
      actions: [
        { action: 'view', title: 'View' },
        { action: 'snooze', title: 'Snooze' },
        { action: 'dismiss', title: 'Dismiss' }
      ],
      requireInteraction: true,
      ...options
    };
  }

  createPromoNotification(title, body, url, options = {}) {
    return {
      type: 'promo',
      title,
      body,
      url,
      deepLink: url,
      actions: [
        { action: 'view', title: 'Learn More' },
        { action: 'dismiss', title: 'Not Now' }
      ],
      ...options
    };
  }

  createSystemNotification(title, body, options = {}) {
    return {
      type: 'system',
      title,
      body,
      tag: 'system',
      ...options
    };
  }
}

module.exports = NotificationBackend;
