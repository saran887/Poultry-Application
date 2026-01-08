const express = require('express');
const router = express.Router();
const { getDailyStats, updateDailyStats } = require('../controllers/statsController');

router.get('/', getDailyStats);
router.post('/update', updateDailyStats);

module.exports = router;
