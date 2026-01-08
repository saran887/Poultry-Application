const express = require('express');
const router = express.Router();
const { getLatestSensorData, updateSensorData, getHistoricalData } = require('../controllers/sensorController');

router.get('/latest', getLatestSensorData);
router.post('/update', updateSensorData);
router.get('/history', getHistoricalData);

module.exports = router;
