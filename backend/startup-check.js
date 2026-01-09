/**
 * Startup Validation Script
 * Checks all critical requirements before starting the server
 */

const fs = require('fs');
const path = require('path');
require('dotenv').config();

const checks = [];
const errors = [];
const warnings = [];

console.log('🔍 Running Pre-Startup Validation...\n');

// Check 1: Environment Variables
console.log('1️⃣  Checking Environment Variables...');
const requiredEnvVars = ['DB_NAME', 'DB_USER', 'DB_PASSWORD', 'DB_HOST', 'DB_PORT', 'JWT_SECRET'];
requiredEnvVars.forEach(envVar => {
  if (!process.env[envVar]) {
    errors.push(`Missing required environment variable: ${envVar}`);
  } else {
    checks.push(`✅ ${envVar} is set`);
  }
});

// Check 2: Database Configuration
console.log('2️⃣  Checking Database Configuration...');
try {
  const sequelize = require('./config/database');
  checks.push('✅ Database configuration loaded');
  
  // Test connection
  sequelize.authenticate()
    .then(() => {
      console.log('✅ Database connection successful\n');
      continueChecks();
    })
    .catch(err => {
      errors.push(`Database connection failed: ${err.message}`);
      continueChecks();
    });
} catch (err) {
  errors.push(`Failed to load database config: ${err.message}`);
  continueChecks();
}

function continueChecks() {
  // Check 3: Required Models
  console.log('3️⃣  Checking Models...');
  const modelFiles = [
    'UserAuth.js',
    'FarmOverview.js',
    'EquipmentStatus.js',
    'Alert.js',
    'DailyStats.js'
  ];
  
  modelFiles.forEach(file => {
    const modelPath = path.join(__dirname, 'models', file);
    if (fs.existsSync(modelPath)) {
      checks.push(`✅ Model ${file} exists`);
    } else {
      errors.push(`Missing model file: ${file}`);
    }
  });

  // Check 4: Required Routes
  console.log('4️⃣  Checking Routes...');
  const routeFiles = [
    'authRoutes.js',
    'sensorRoutes.js',
    'equipmentRoutes.js',
    'statsRoutes.js',
    'alertRoutes.js'
  ];
  
  routeFiles.forEach(file => {
    const routePath = path.join(__dirname, 'routes', file);
    if (fs.existsSync(routePath)) {
      checks.push(`✅ Route ${file} exists`);
    } else {
      errors.push(`Missing route file: ${file}`);
    }
  });

  // Check 5: Camera Configuration (Optional)
  console.log('5️⃣  Checking Camera Configuration...');
  const cameraVars = ['CAMERA_IP', 'CAMERA_USERNAME', 'CAMERA_PASSWORD'];
  const cameraConfigured = cameraVars.every(v => process.env[v]);
  if (cameraConfigured) {
    checks.push('✅ Camera configuration is complete');
  } else {
    warnings.push('⚠️  Camera configuration incomplete (optional)');
  }

  // Check 6: Python Script for Camera
  console.log('6️⃣  Checking Python Camera Script...');
  const pythonScript = path.join(__dirname, 'directstream_ipcamera.py');
  if (fs.existsSync(pythonScript)) {
    checks.push('✅ Python camera script exists');
  } else {
    warnings.push('⚠️  Python camera script not found (optional)');
  }

  // Check 7: Port Availability
  console.log('7️⃣  Checking Port Configuration...');
  const port = process.env.PORT || 3000;
  checks.push(`✅ Server will use port ${port}`);

  // Display Results
  console.log('\n' + '='.repeat(60));
  console.log('📊 VALIDATION RESULTS');
  console.log('='.repeat(60) + '\n');

  if (checks.length > 0) {
    console.log('✅ PASSED CHECKS:');
    checks.forEach(check => console.log(`   ${check}`));
    console.log('');
  }

  if (warnings.length > 0) {
    console.log('⚠️  WARNINGS:');
    warnings.forEach(warning => console.log(`   ${warning}`));
    console.log('');
  }

  if (errors.length > 0) {
    console.log('❌ ERRORS:');
    errors.forEach(error => console.log(`   ❌ ${error}`));
    console.log('\n' + '='.repeat(60));
    console.log('❌ VALIDATION FAILED - Please fix the errors above');
    console.log('='.repeat(60) + '\n');
    process.exit(1);
  } else {
    console.log('='.repeat(60));
    console.log('✅ ALL CRITICAL CHECKS PASSED');
    console.log('='.repeat(60) + '\n');
    console.log('🚀 Server is ready to start!\n');
    process.exit(0);
  }
}
