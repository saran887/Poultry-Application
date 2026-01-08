const DailyStats = require('../models/DailyStats');

const getDailyStats = async (req, res) => {
  try {
    const stats = await DailyStats.findAll({
      order: [['date', 'ASC']],
      limit: 7
    });
    res.json(stats);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

const updateDailyStats = async (req, res) => {
  try {
    const { date, avgTemperature, avgHumidity, waterUsage, feedUsage, equipmentUptime } = req.body;
    const [stat, created] = await DailyStats.findOrCreate({
      where: { date },
      defaults: { avgTemperature, avgHumidity, waterUsage, feedUsage, equipmentUptime }
    });

    if (!created) {
      stat.avgTemperature = avgTemperature;
      stat.avgHumidity = avgHumidity;
      stat.waterUsage = waterUsage;
      stat.feedUsage = feedUsage;
      stat.equipmentUptime = equipmentUptime;
      await stat.save();
    }

    res.json(stat);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

module.exports = { getDailyStats, updateDailyStats };
