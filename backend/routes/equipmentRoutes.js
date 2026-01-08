const express = require('express');
const router = express.Router();
const { getLatestEquipmentStatus, updateEquipmentStatus } = require('../controllers/equipmentController');

router.get('/latest', getLatestEquipmentStatus);
router.post('/update', updateEquipmentStatus);

module.exports = router;
