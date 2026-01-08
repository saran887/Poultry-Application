const EquipmentStatus = require('../models/EquipmentStatus');

const getLatestEquipmentStatus = async (req, res) => {
  try {
    let status = await EquipmentStatus.findOne({
      order: [['updatedAt', 'DESC']]
    });

    if (!status) {
      status = await EquipmentStatus.create({
        fanOn: false,
        foggerOn: false,
        sprinklerOn: false,
        motorOn: false,
        lightOn: false,
        feederOn: false,
        autoMode: true
      });
    }

    res.json(status);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

const updateEquipmentStatus = async (req, res) => {
  try {
    const { fanOn, foggerOn, sprinklerOn, motorOn, lightOn, feederOn, autoMode } = req.body;
    
    // Find the latest status record and update it, or create if none exists
    let status = await EquipmentStatus.findOne({
      order: [['updatedAt', 'DESC']]
    });

    if (!status) {
      status = await EquipmentStatus.create({
        fanOn,
        foggerOn,
        sprinklerOn,
        motorOn,
        lightOn,
        feederOn,
        autoMode: autoMode !== undefined ? autoMode : true,
        updatedAt: new Date()
      });
    } else {
      await status.update({
        fanOn: fanOn !== undefined ? fanOn : status.fanOn,
        foggerOn: foggerOn !== undefined ? foggerOn : status.foggerOn,
        sprinklerOn: sprinklerOn !== undefined ? sprinklerOn : status.sprinklerOn,
        motorOn: motorOn !== undefined ? motorOn : status.motorOn,
        lightOn: lightOn !== undefined ? lightOn : status.lightOn,
        feederOn: feederOn !== undefined ? feederOn : status.feederOn,
        autoMode: autoMode !== undefined ? autoMode : status.autoMode,
        updatedAt: new Date()
      });
    }

    console.log(`[Database] Equipment status updated: Fan=${status.fanOn}, Fogger=${status.foggerOn}, AutoMode=${status.autoMode}`);
    
    // Emit the update to all connected clients
    const io = req.app.get('socketio');
    if (io) {
      io.emit('equipmentUpdate', status);
    }

    res.json(status);
  } catch (error) {
    console.error('[Database Error]', error.message);
    res.status(500).json({ error: error.message });
  }
};

module.exports = { getLatestEquipmentStatus, updateEquipmentStatus };

