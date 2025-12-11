const express = require('express');
const router = express.Router();
const { optionalAuth } = require('./middleware/auth');

/**
 * Characters Bridge API
 * Maps simple /api/characters endpoints to the actual custom-characters-api
 * This bridges the frontend API expectations with the backend implementation
 */

/**
 * Middleware to extract userId from authenticated user
 * Requires optionalAuth middleware to run first
 * @param {Request} req - Express request object
 * @param {Response} res - Express response object
 * @param {Function} next - Next middleware function
 */
const extractUserId = (req, res, next) => {
  // Extract userId from authenticated user (set by optionalAuth middleware)
  if (req.user && req.user.id) {
    req.userId = req.user.id;
    console.log(`[CHARACTERS] User authenticated: ${req.userId}`);
    next();
  } else {
    // No authenticated user - return 401 for protected endpoints
    console.warn('[CHARACTERS] No authenticated user found');
    return res.status(401).json({
      error: 'Authentication required',
      message: 'Please log in to access your characters',
      code: 'AUTH_REQUIRED'
    });
  }
};

module.exports = {
  setupCharactersBridgeAPI: (app, db) => {
    /**
     * GET /api/characters
     * Get all characters for the current user
     */
    app.get('/api/characters', optionalAuth, extractUserId, async (req, res) => {
      try {
        const userId = req.userId;

        // Query custom_characters table
        const result = await db.query(
          `SELECT * FROM custom_characters WHERE user_id = ? ORDER BY created_at DESC`,
          [userId]
        );

        const characters = result && result.rows ? result.rows : [];
        res.json(characters);
      } catch (error) {
        console.error('Error fetching characters:', error);
        res.status(500).json({
          error: 'Failed to fetch characters',
          message: error.message
        });
      }
    });

    /**
     * GET /api/characters/:id
     * Get a specific character by ID
     */
    app.get('/api/characters/:id', optionalAuth, extractUserId, async (req, res) => {
      try {
        const { id } = req.params;
        const userId = req.userId;

        const result = await db.query(
          `SELECT * FROM custom_characters WHERE id = ? AND user_id = ?`,
          [id, userId]
        );

        const character = result && result.rows && result.rows[0];
        if (!character) {
          return res.status(404).json({ error: 'Character not found' });
        }

        res.json(character);
      } catch (error) {
        console.error('Error fetching character:', error);
        res.status(500).json({
          error: 'Failed to fetch character',
          message: error.message
        });
      }
    });

    /**
     * POST /api/characters
     * Create a new character
     * UPDATED: Allow free trial users to create 1 temporary character
     */
    app.post('/api/characters', optionalAuth, async (req, res) => {
      try {
        // ALLOW FREE TRIAL: Generate temporary user ID for unauthenticated users
        const userId = req.user?.id || `trial_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
        const isTrialUser = !req.user?.id;

        const {
          name,
          bio,
          avatar,
          personality,
          systemPrompt,
          voiceSettings
        } = req.body;

        // Validation
        if (!name || !name.trim()) {
          return res.status(400).json({ error: 'Character name is required' });
        }

        // Trial users limited to 1 character
        if (isTrialUser) {
          try {
            const existingCharacters = await db.query(
              `SELECT COUNT(*) as count FROM custom_characters WHERE user_id = ?`,
              [userId]
            );

            const count = existingCharacters[0]?.count || 0;
            if (count >= 1) {
              return res.status(403).json({
                error: 'Free trial limited to 1 character',
                message: 'Create an account to create more characters',
                code: 'TRIAL_LIMIT_REACHED'
              });
            }
          } catch (countError) {
            console.warn('Could not check trial character count:', countError);
            // Allow to proceed anyway (better UX)
          }
        }

        // Generate ID
        const characterId = `char_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;

        // Insert into database
        await db.query(
          `INSERT INTO custom_characters (
            id, user_id, name, description, personality, system_prompt,
            image, created_at, updated_at, config
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
          [
            characterId,
            userId,
            name.trim(),
            bio || '',
            personality || '',
            systemPrompt || '',
            avatar || '/assets/default-avatar.png',
            new Date().toISOString(),
            new Date().toISOString(),
            JSON.stringify(voiceSettings || {})
          ]
        );

        // Fetch and return the created character
        const result = await db.query(
          `SELECT * FROM custom_characters WHERE id = ?`,
          [characterId]
        );

        const character = result && result.rows && result.rows[0];

        // Add trial indicator to response
        const response = {
          ...character,
          isTrialCharacter: isTrialUser
        };

        if (isTrialUser) {
          response.message = 'Character created for trial! Create an account to save permanently.';
          response.trialLimited = true;
        }

        res.status(201).json(response);
      } catch (error) {
        console.error('Error creating character:', error);
        res.status(500).json({
          error: 'Failed to create character',
          message: error.message
        });
      }
    });

    /**
     * PATCH /api/characters/:id
     * Update an existing character
     */
    app.patch('/api/characters/:id', optionalAuth, extractUserId, async (req, res) => {
      try {
        const { id } = req.params;
        const userId = req.userId;
        const updates = req.body;

        // Verify character belongs to user
        const result = await db.query(
          `SELECT * FROM custom_characters WHERE id = ? AND user_id = ?`,
          [id, userId]
        );

        if (!result || !result.rows || !result.rows[0]) {
          return res.status(404).json({ error: 'Character not found' });
        }

        // Build update query
        const allowedFields = ['name', 'description', 'personality', 'system_prompt', 'image', 'config'];
        const updateFields = [];
        const updateValues = [];

        for (const field of allowedFields) {
          if (updates[field] !== undefined) {
            updateFields.push(`${field} = ?`);
            updateValues.push(updates[field]);
          }
        }

        if (updateFields.length === 0) {
          return res.status(400).json({ error: 'No valid fields to update' });
        }

        // Add updated_at
        updateFields.push('updated_at = ?');
        updateValues.push(new Date().toISOString());
        updateValues.push(id);
        updateValues.push(userId);

        // Execute update
        await db.query(
          `UPDATE custom_characters SET ${updateFields.join(', ')}
           WHERE id = ? AND user_id = ?`,
          updateValues
        );

        // Fetch and return updated character
        const updatedResult = await db.query(
          `SELECT * FROM custom_characters WHERE id = ?`,
          [id]
        );

        const character = updatedResult && updatedResult.rows && updatedResult.rows[0];
        res.json(character);
      } catch (error) {
        console.error('Error updating character:', error);
        res.status(500).json({
          error: 'Failed to update character',
          message: error.message
        });
      }
    });

    /**
     * DELETE /api/characters/:id
     * Delete a character
     */
    app.delete('/api/characters/:id', optionalAuth, extractUserId, async (req, res) => {
      try {
        const { id } = req.params;
        const userId = req.userId;

        // Verify character belongs to user
        const result = await db.query(
          `SELECT * FROM custom_characters WHERE id = ? AND user_id = ?`,
          [id, userId]
        );

        if (!result || !result.rows || !result.rows[0]) {
          return res.status(404).json({ error: 'Character not found' });
        }

        // Delete character
        await db.query(
          `DELETE FROM custom_characters WHERE id = ? AND user_id = ?`,
          [id, userId]
        );

        res.json({ success: true, message: 'Character deleted' });
      } catch (error) {
        console.error('Error deleting character:', error);
        res.status(500).json({
          error: 'Failed to delete character',
          message: error.message
        });
      }
    });

    console.log('✅ Characters Bridge API endpoints configured (/api/characters)');
  }
};
