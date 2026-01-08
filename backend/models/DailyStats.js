const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const DailyStats = sequelize.define('DailyStats', {
  id: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true
  },
  date: {
    type: DataTypes.DATEONLY,
    allowNull: false
  },
  avgTemperature: {
    type: DataTypes.FLOAT,
    defaultValue: 0
  },
  avgHumidity: {
    type: DataTypes.FLOAT,
    defaultValue: 0
  },
  waterUsage: {
    type: DataTypes.FLOAT,
    defaultValue: 0
  },
  feedUsage: {
    type: DataTypes.FLOAT,
    defaultValue: 0
  },
  equipmentUptime: {
    type: DataTypes.JSONB, // Store { fan: 80, fogger: 20, ... }
    defaultValue: { fan: 0, fogger: 0, sprinkler: 0, motor: 0 }
  }
}, {
  tableName: 'daily_stats'
});

module.exports = DailyStats;
