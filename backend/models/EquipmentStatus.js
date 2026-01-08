const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const EquipmentStatus = sequelize.define('EquipmentStatus', {
  id: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true
  },
  fanOn: {
    type: DataTypes.BOOLEAN,
    defaultValue: false
  },
  foggerOn: {
    type: DataTypes.BOOLEAN,
    defaultValue: false
  },
  sprinklerOn: {
    type: DataTypes.BOOLEAN,
    defaultValue: false
  },
  motorOn: {
    type: DataTypes.BOOLEAN,
    defaultValue: false
  },
  lightOn: {
    type: DataTypes.BOOLEAN,
    defaultValue: false
  },
  feederOn: {
    type: DataTypes.BOOLEAN,
    defaultValue: false
  },
  autoMode: {
    type: DataTypes.BOOLEAN,
    defaultValue: true
  },
  updatedAt: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW
  }
}, {
  tableName: 'equipment_status',
  timestamps: false
});

module.exports = EquipmentStatus;
