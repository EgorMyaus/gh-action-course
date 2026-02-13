require('dotenv').config();
const express = require('express');
const cors = require('cors');
const contactsRouter = require('./routes/contacts');

const app = express();
const PORT = process.env.PORT || 3001;

app.use(cors());
app.use(express.json());

app.get('/health', (req, res) => {
  res.json({ 
    status: 'healthy',
    environment: process.env.NODE_ENV || 'development',
    dataSource: process.env.USE_DATABASE === 'true' ? 'PostgreSQL' : 'In-Memory'
  });
});

app.use('/api/contacts', contactsRouter);

app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ error: 'Something went wrong!' });
});

app.listen(PORT, () => {
  console.log(`API Server running on port ${PORT}`);
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`Data source: ${process.env.USE_DATABASE === 'true' ? 'PostgreSQL' : 'In-Memory JSON'}`);
});
