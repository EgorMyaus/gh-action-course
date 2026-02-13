import axios from 'axios';

const API_URL = process.env.REACT_APP_API_URL || 'http://localhost:3001/api';

const api = axios.create({
  baseURL: API_URL,
  timeout: 5000,
  headers: {
    'Content-Type': 'application/json',
  },
});

export const contactsApi = {
  getAll: async () => {
    const response = await api.get('/contacts');
    return response.data;
  },

  getById: async (id) => {
    const response = await api.get(`/contacts/${id}`);
    return response.data;
  },

  create: async (contact) => {
    const response = await api.post('/contacts', contact);
    return response.data;
  },

  update: async (id, contact) => {
    const response = await api.put(`/contacts/${id}`, contact);
    return response.data;
  },

  delete: async (id) => {
    const response = await api.delete(`/contacts/${id}`);
    return response.data;
  },

  reset: async () => {
    const response = await api.post('/contacts/reset');
    return response.data;
  },
};

export const healthCheck = async () => {
  try {
    const response = await api.get('/health');
    return response.data;
  } catch (error) {
    return { status: 'unavailable', error: error.message };
  }
};

export default api;
