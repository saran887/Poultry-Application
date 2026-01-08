const express = require('express');
const router = express.Router();
const { getAlerts, createAlert, resolveAlert } = require('../controllers/alertController');

router.get('/', getAlerts);
router.post('/', createAlert);
router.patch('/:id/resolve', resolveAlert);

module.exports = router;
