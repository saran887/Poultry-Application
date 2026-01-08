const Alert = require('../models/Alert');

const getAlerts = async (req, res) => {
  try {
    const alerts = await Alert.findAll({
      order: [['timestamp', 'DESC']],
      limit: 50
    });
    res.json(alerts);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

const createAlert = async (req, res) => {
  try {
    const { severity, message } = req.body;
    const alert = await Alert.create({ severity, message });
    res.status(201).json(alert);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
};

const resolveAlert = async (req, res) => {
  try {
    const { id } = req.params;
    const alert = await Alert.findByPk(id);
    if (!alert) return res.status(404).json({ error: 'Alert not found' });
    
    alert.resolved = true;
    await alert.save();
    res.json(alert);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

module.exports = { getAlerts, createAlert, resolveAlert };
