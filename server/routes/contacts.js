const express = require('express');
const router = express.Router();
const { getPool } = require('../config/database');

const contactsJson = require('../../src/contacts.json');
let inMemoryContacts = [...contactsJson];

const useDatabase = () => process.env.USE_DATABASE === 'true';

router.get('/', async (req, res) => {
  try {
    if (useDatabase()) {
      const pool = getPool();
      const result = await pool.query('SELECT * FROM contacts ORDER BY name');
      return res.json(result.rows);
    }
    res.json(inMemoryContacts);
  } catch (err) {
    console.error('Error fetching contacts:', err);
    res.status(500).json({ error: 'Failed to fetch contacts' });
  }
});

router.get('/:id', async (req, res) => {
  const { id } = req.params;
  try {
    if (useDatabase()) {
      const pool = getPool();
      const result = await pool.query('SELECT * FROM contacts WHERE id = $1', [id]);
      if (result.rows.length === 0) {
        return res.status(404).json({ error: 'Contact not found' });
      }
      return res.json(result.rows[0]);
    }
    const contact = inMemoryContacts.find((c, idx) => idx === parseInt(id));
    if (!contact) {
      return res.status(404).json({ error: 'Contact not found' });
    }
    res.json(contact);
  } catch (err) {
    console.error('Error fetching contact:', err);
    res.status(500).json({ error: 'Failed to fetch contact' });
  }
});

router.post('/', async (req, res) => {
  const { name, gender, phone, street, city } = req.body;
  
  if (!name) {
    return res.status(400).json({ error: 'Name is required' });
  }

  try {
    if (useDatabase()) {
      const pool = getPool();
      const result = await pool.query(
        'INSERT INTO contacts (name, gender, phone, street, city) VALUES ($1, $2, $3, $4, $5) RETURNING *',
        [name, gender, phone, street, city]
      );
      return res.status(201).json(result.rows[0]);
    }
    const newContact = { name, gender, phone, street, city };
    inMemoryContacts.push(newContact);
    res.status(201).json(newContact);
  } catch (err) {
    console.error('Error creating contact:', err);
    res.status(500).json({ error: 'Failed to create contact' });
  }
});

router.put('/:id', async (req, res) => {
  const { id } = req.params;
  const { name, gender, phone, street, city } = req.body;

  try {
    if (useDatabase()) {
      const pool = getPool();
      const result = await pool.query(
        'UPDATE contacts SET name = $1, gender = $2, phone = $3, street = $4, city = $5, updated_at = CURRENT_TIMESTAMP WHERE id = $6 RETURNING *',
        [name, gender, phone, street, city, id]
      );
      if (result.rows.length === 0) {
        return res.status(404).json({ error: 'Contact not found' });
      }
      return res.json(result.rows[0]);
    }
    const idx = parseInt(id);
    if (idx < 0 || idx >= inMemoryContacts.length) {
      return res.status(404).json({ error: 'Contact not found' });
    }
    inMemoryContacts[idx] = { name, gender, phone, street, city };
    res.json(inMemoryContacts[idx]);
  } catch (err) {
    console.error('Error updating contact:', err);
    res.status(500).json({ error: 'Failed to update contact' });
  }
});

router.delete('/:id', async (req, res) => {
  const { id } = req.params;

  try {
    if (useDatabase()) {
      const pool = getPool();
      const result = await pool.query('DELETE FROM contacts WHERE id = $1 RETURNING *', [id]);
      if (result.rows.length === 0) {
        return res.status(404).json({ error: 'Contact not found' });
      }
      return res.json({ message: 'Contact deleted', contact: result.rows[0] });
    }
    const idx = parseInt(id);
    if (idx < 0 || idx >= inMemoryContacts.length) {
      return res.status(404).json({ error: 'Contact not found' });
    }
    const deleted = inMemoryContacts.splice(idx, 1);
    res.json({ message: 'Contact deleted', contact: deleted[0] });
  } catch (err) {
    console.error('Error deleting contact:', err);
    res.status(500).json({ error: 'Failed to delete contact' });
  }
});

router.post('/reset', (req, res) => {
  if (useDatabase()) {
    return res.status(400).json({ error: 'Reset not available in database mode' });
  }
  inMemoryContacts = [...contactsJson];
  res.json({ message: 'Contacts reset to initial state', count: inMemoryContacts.length });
});

module.exports = router;
