const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const FarmOverview = sequelize.define('FarmOverview', {
  device_id: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    comment: '1 = Temperature, 2 = Humidity, 3 = Water Tank'
  },
  value: {
    type: DataTypes.REAL,
    allowNull: false
  },
  recorded_at: {
    type: DataTypes.DATE(0), // TIMESTAMP(0) - no microseconds
    primaryKey: true,
    defaultValue: DataTypes.NOW
  }
}, {
  tableName: 'farm_overview',
  timestamps: false
});

module.exports = FarmOverview;
