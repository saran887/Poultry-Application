const FarmOverview = require('./models/FarmOverview');
const sequelize = require('./config/database');

async function check() {
  try {
    await sequelize.authenticate();
    const count = await FarmOverview.count();
    console.log('Total records in farm_overview:', count);
    
    if (count > 0) {
      const latest = await FarmOverview.findAll({
        order: [['recorded_at', 'DESC']],
        limit: 3
      });
      console.log('Last 3 records:', JSON.stringify(latest, null, 2));
    }
  } catch (err) {
    console.error('Check Error:', err.message);
  } finally {
    process.exit();
  }
}

check();
