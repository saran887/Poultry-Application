const FarmOverview = require('../models/FarmOverview');
const { Op } = require('sequelize');

const getLatestSensorData = async (req, res) => {
  try {
    // Get the most recent 3 records (one for each device)
    const data = await FarmOverview.findAll({
      order: [['recorded_at', 'DESC'], ['device_id', 'ASC']],
      limit: 3
    });
    
    if (data.length === 0) {
      return res.json({ temperature: 0, humidity: 0, waterLevel: 0, timestamp: new Date() });
    }

    const result = {
      temperature: 0,
      humidity: 0,
      waterLevel: 0,
      timestamp: data[0].recorded_at
    };

    data.forEach(item => {
      if (item.device_id === 1) result.temperature = item.value;
      if (item.device_id === 2) result.humidity = item.value;
      if (item.device_id === 3) result.waterLevel = item.value;
    });

    res.json(result);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

const updateSensorData = async (req, res) => {
  try {
    const { device_id, value } = req.body;
    const recorded_at = new Date();
    recorded_at.setMilliseconds(0); // TIMESTAMP(0)

    const newData = await FarmOverview.create({
      device_id,
      value,
      recorded_at
    });

    // Notify clients of manual update
    const io = req.app.get('socketio');
    if (io) {
      io.emit('sensorManualUpdate', newData);
    }

    res.status(201).json(newData);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
};

const getHistoricalData = async (req, res) => {
  try {
    const { range } = req.query; 
    let limit = 24 * 3; // 24 readings * 3 devices for temp/hum/water
    
    // This is a simplified fetch; in production, you might want to pivot the data in SQL
    const data = await FarmOverview.findAll({
      order: [['recorded_at', 'DESC'], ['device_id', 'ASC']],
      limit: limit
    });
    
    // Group by timestamp for frontend
    const grouped = [];
    let current = null;
    
    data.forEach(item => {
      const time = item.recorded_at.toISOString();
      if (!current || current.timestamp !== time) {
        if (current) grouped.push(current);
        current = { timestamp: time, temperature: 0, humidity: 0, waterLevel: 0 };
      }
      if (item.device_id === 1) current.temperature = item.value;
      if (item.device_id === 2) current.humidity = item.value;
      if (item.device_id === 3) current.waterLevel = item.value;
    });
    if (current) grouped.push(current);

    res.json(grouped.reverse());
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

module.exports = { getLatestSensorData, updateSensorData, getHistoricalData };
