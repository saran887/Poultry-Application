require('dotenv').config();
const express = require('express');
const cors = require('cors');
const http = require('http');
const { Server } = require('socket.io');
const { spawn } = require('child_process');
const path = require('path');
const sequelize = require('./config/database');
const UserAuth = require('./models/UserAuth');
const FarmOverview = require('./models/FarmOverview');
const EquipmentStatus = require('./models/EquipmentStatus');
const Alert = require('./models/Alert');
const DailyStats = require('./models/DailyStats');
const readline = require('readline');

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
  }
});

// HTTP proxy for camera stream
const httpProxy = require('http');
const https = require('https');

// Make io accessible to our routers
app.set('socketio', io);

const PORT = process.env.PORT || 3000;

app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  exposedHeaders: ['Content-Type']
}));
app.use(express.json());

// Socket.io Connection Logic
io.on('connection', async (socket) => {
  console.log(`\n[Socket] New client connected: ${socket.id}`);
  
  try {
    // Send latest sensor data
    const lastSensor = await FarmOverview.findOne({
      order: [['recorded_at', 'DESC']]
    });
    
    // We need to fetch all 3 devices to construct the full sensorUpdate object
    const latestValues = await FarmOverview.findAll({
      limit: 3,
      order: [['recorded_at', 'DESC']]
    });

    const sensorData = {
      temperature: 0,
      humidity: 0,
      waterLevel: 0,
      timestamp: new Date()
    };

    latestValues.forEach(v => {
      if (v.device_id === 1) sensorData.temperature = v.value;
      if (v.device_id === 2) sensorData.humidity = v.value;
      if (v.device_id === 3) sensorData.waterLevel = v.value;
      sensorData.timestamp = v.recorded_at;
    });

    socket.emit('sensorUpdate', sensorData);

    // Send latest equipment status
    const status = await EquipmentStatus.findOne({
      order: [['updatedAt', 'DESC']]
    });
    if (status) {
      socket.emit('equipmentUpdate', status);
    }
  } catch (err) {
    console.error('[Socket Error] Initial state send failed:', err.message);
  }

  socket.on('disconnect', () => {
    console.log(`[Socket] Client disconnected: ${socket.id}`);
  });

  // Handle high-speed equipment control via Socket.io for "Sudden Change"
  socket.on('toggleEquipment', async (data) => {
    try {
      const EquipmentStatus = require('./models/EquipmentStatus');
      let status = await EquipmentStatus.findOne({ order: [['updatedAt', 'DESC']] });
      if (status) {
        await status.update({
          ...data,
          updatedAt: new Date()
        });
        // Broadcast to all clients including sender for confirmation
        io.emit('equipmentUpdate', status);
        console.log(`[Socket Control] Equipment updated: ${JSON.stringify(data)}`);
      }
    } catch (err) {
      console.error('[Socket Control Error]', err.message);
    }
  });
});

// Network Request Logger Middleware
app.use((req, res, next) => {
  const timestamp = new Date().toISOString();
  const clientIp = req.ip || req.connection.remoteAddress;
  console.log(`\n[${timestamp}] 📡 ${req.method} ${req.url}`);
  console.log(`   Client: ${clientIp}`);
  console.log(`   User-Agent: ${req.get('user-agent') || 'Unknown'}`);
  if (Object.keys(req.body).length > 0) {
    console.log(`   Body:`, JSON.stringify(req.body));
  }
  
  // Log response
  const originalSend = res.send;
  res.send = function(data) {
    console.log(`   Response: ${res.statusCode} - ${data.length || 0} bytes`);
    originalSend.call(this, data);
  };
  
  next();
});

// Root Route
app.get('/', (req, res) => {
  res.send('Server is up and running.');
});

// Ingestion Logic: Automatic mock data generation is DISABLED
const startIngestion = () => {
  console.log('[Ingestion] Automatic mock data generation is currently DISABLED.');
  console.log('[Ingestion] Use the CLI below to enter data manually.');
  
  /* 
  // Code preserved for future use:
  const insertData = async () => {
    try {
      const now = new Date();
      now.setMilliseconds(0);
      
      const records = [
        { device_id: 1, value: parseFloat((25 + Math.random() * 10).toFixed(2)), recorded_at: now },
        { device_id: 2, value: parseFloat((50 + Math.random() * 30).toFixed(2)), recorded_at: now },
        { device_id: 3, value: parseFloat((20 + Math.random() * 80).toFixed(2)), recorded_at: now }
      ];
      
      await FarmOverview.bulkCreate(records);
      io.emit('sensorUpdate', {
        temperature: records[0].value,
        humidity: records[1].value,
        waterLevel: records[2].value,
        timestamp: now
      });
    } catch (err) {
      console.error('[Ingestion Error]', err.message);
    }
  };
  */
};

// Start Python Camera Stream Server
const startPythonStream = () => {
  // Try to use common python paths or just 'python'
  let pythonPath = 'python'; // Default for most systems
  if (process.platform === 'win32') {
    // On Windows, try 'python' first, then 'python.exe'
    pythonPath = 'python';
  } else {
    pythonPath = 'python3';
  }
  
  const scriptPath = path.join(__dirname, 'directstream_ipcamera.py');
  
  console.log(`[Python] Starting WebSocket stream feeder using command: ${pythonPath}`);
  
  const pythonProcess = spawn(pythonPath, [scriptPath], {
    stdio: ['ignore', 'pipe', 'inherit'],
    env: process.env
  });

  let buffer = '';
  pythonProcess.stdout.on('data', (data) => {
    buffer += data.toString();
    
    // Extract frames using delimiters
    let startIdx;
    while ((startIdx = buffer.indexOf('FRAME_START')) !== -1) {
      let endIdx = buffer.indexOf('FRAME_END', startIdx);
      if (endIdx !== -1) {
        const frameData = buffer.substring(startIdx + 11, endIdx);
        io.emit('cameraFrame', frameData);
        buffer = buffer.substring(endIdx + 9);
      } else {
        break; // Wait for more data
      }
    }
  });

  pythonProcess.on('error', (err) => {
    console.error('[Python Error] Failed to start Python process:', err.message);
  });

  pythonProcess.on('close', (code) => {
    console.log(`[Python] Process exited with code ${code}`);
    // Restart after 5 seconds if it crashes
    setTimeout(startPythonStream, 5000);
  });
};

// --- AUTOMATION LOGIC ---
const runAutomationLogic = async (temp, hum, water, io) => {
  try {
    const EquipmentStatus = require('./models/EquipmentStatus');
    let status = await EquipmentStatus.findOne({ order: [['updatedAt', 'DESC']] });
    
    if (!status) {
      status = await EquipmentStatus.create({
        fanOn: false, foggerOn: false, sprinklerOn: false, 
        motorOn: false, lightOn: false, feederOn: false, autoMode: true
      });
    }

    // Only run if Auto Mode is ON
    if (!status.autoMode) return;

    let changed = false;
    let updates = {};

    // 1. Fan & Fogger: High temp logic (> 32°C)
    if (temp > 32) {
      if (!status.fanOn) { updates.fanOn = true; changed = true; }
      if (!status.foggerOn) { updates.foggerOn = true; changed = true; }
    } else if (temp < 31) {
      if (status.fanOn) { updates.fanOn = false; changed = true; }
      if (status.foggerOn) { updates.foggerOn = false; changed = true; }
    }

    // 2. Sprinkler: High temp humidity logic
    if (temp > 33 && hum < 40) {
      if (!status.sprinklerOn) { updates.sprinklerOn = true; changed = true; }
    } else if (temp < 32 || hum > 50) {
      if (status.sprinklerOn) { updates.sprinklerOn = false; changed = true; }
    }

    // 3. Water Motor: 30% to 95% logic
    if (water < 30) {
      if (!status.motorOn) { updates.motorOn = true; changed = true; }
    } else if (water >= 95) {
      if (status.motorOn) { updates.motorOn = false; changed = true; }
    }

    // 4. Light: Time-based (6 PM - 6 AM)
    const hour = new Date().getHours();
    const shouldLightBeOn = (hour >= 18 || hour < 6);
    if (status.lightOn !== shouldLightBeOn) {
      updates.lightOn = shouldLightBeOn;
      changed = true;
    }

    if (changed) {
      await status.update(updates);
      console.log(`[Automation] Auto-updated equipment: ${JSON.stringify(updates)}`);
      io.emit('equipmentUpdate', status);
    }
  } catch (err) {
    console.error('[Automation Error]', err.message);
  }
};

// Manual Data Entry CLI
const startManualCLI = () => {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
    prompt: '\n[Manual Mock] Enter values (temp hum water) or "exit": '
  });

  console.log('\n--- MANUAL DATA ENTRY ENABLED ---');
  console.log('Type three numbers separated by spaces to update sensors.');
  console.log('Example: 25.5 60 85');
  rl.prompt();

  rl.on('line', async (line) => {
    const input = line.trim();
    if (input.toLowerCase() === 'exit') {
      console.log('Exiting manual entry...');
      rl.close();
      return;
    }

    const [temp, hum, water] = input.split(' ').map(Number);

    if (isNaN(temp) || isNaN(hum) || isNaN(water)) {
      console.log('❌ Invalid input. Use format: temp humidity water (e.g. 26.5 55 90)');
    } else {
      try {
        const now = new Date();
        now.setMilliseconds(0);
        
        const records = [
          { device_id: 1, value: temp, recorded_at: now },
          { device_id: 2, value: hum, recorded_at: now },
          { device_id: 3, value: water, recorded_at: now }
        ];
        
        await FarmOverview.bulkCreate(records);
        console.log(`✅ MANUALLY INSERTED: Temp: ${temp}, Hum: ${hum}, Water: ${water}`);
        
        // Emit update via Socket.io
        io.emit('sensorUpdate', {
          temperature: temp,
          humidity: hum,
          waterLevel: water,
          timestamp: now
        });

        // Run Automation logic on backend for "Sudden Change"
        await runAutomationLogic(temp, hum, water, io);
      } catch (err) {
        console.error('Error inserting manual data:', err.message);
      }
    }
    rl.prompt();
  });
};

// Seed default credentials
const seedDefaults = async () => {
  try {
    const adminExists = await UserAuth.findByPk('admin@gmail.com');
    if (!adminExists) {
      await UserAuth.create({ email: 'admin@gmail.com', password: 'admin123', role: 'admin' });
      console.log('[Seed] Admin user created');
    }
    const userExists = await UserAuth.findByPk('user@gmail.com');
    if (!userExists) {
      await UserAuth.create({ email: 'user@gmail.com', password: 'user123', role: 'user' });
      console.log('[Seed] Regular user created');
    }

    // Seed some initial stats if empty
    const statsCount = await DailyStats.count();
    if (statsCount === 0) {
      const today = new Date().toISOString().split('T')[0];
      await DailyStats.create({
        date: today,
        avgTemperature: 28.5,
        avgHumidity: 62.0,
        waterUsage: 120.5,
        feedUsage: 85.0,
        equipmentUptime: { fan: 45, fogger: 10, sprinkler: 5, motor: 20 }
      });
      console.log('[Seed] Initial daily stats created');
    }

    // Seed an alert
    const alertCount = await Alert.count();
    if (alertCount === 0) {
      await Alert.create({
        severity: 'low',
        message: 'System initialized successfully',
      });
    }
  } catch (err) {
    console.error('[Seed Error]', err.message);
  }
};

// Sync and Start
sequelize.sync({ alter: true })
  .then(async () => {
    console.log('PostgreSQL connected and synced');
    await seedDefaults();
    startIngestion();
    startPythonStream();
    startManualCLI();
  })
  .catch((err) => console.error('PostgreSQL connection error:', err));

// Camera Stream Proxy Routes
app.get('/api/camera/video_feed', (req, res) => {
  const options = {
    hostname: '127.0.0.1',
    port: 5000,
    path: '/video_feed',
    method: 'GET'
  };

  const proxyReq = httpProxy.request(options, (proxyRes) => {
    // Set headers for MJPEG
    res.setHeader('Content-Type', 'multipart/x-mixed-replace; boundary=frame');
    res.setHeader('Cache-Control', 'no-cache, private, max-age=0, no-store, must-revalidate');
    res.setHeader('Pragma', 'no-cache');
    res.setHeader('Expires', '0');
    res.setHeader('Connection', 'close'); // Try close to avoid buffering
    
    // Write data as it comes
    proxyRes.on('data', (chunk) => {
      res.write(chunk);
    });
    
    proxyRes.on('end', () => {
      res.end();
    });
    
    proxyRes.on('error', (err) => {
      console.error('[Proxy Stream Error]', err.message);
      res.end();
    });
  });

  proxyReq.on('error', (err) => {
    console.error('[Proxy Req Error]', err.message);
    if (!res.headersSent) res.status(503).send('Stream error');
  });

  proxyReq.end();
});

app.get('/api/camera/status', (req, res) => {
  console.log('[Camera Proxy] Status check');
  
  const options = {
    hostname: '127.0.0.1',
    port: 5000,
    path: '/',
    method: 'GET',
    timeout: 3000
  };

  const proxy = httpProxy.request(options, (proxyRes) => {
    if (proxyRes.statusCode === 200) {
      res.json({ status: 'online', message: 'Camera stream is available' });
    } else {
      res.status(503).json({ status: 'error', message: 'Camera stream error' });
    }
  });

  proxy.on('error', (err) => {
    console.error('[Camera Status Error]', err.message);
    res.status(503).json({ status: 'offline', message: 'Camera stream unavailable' });
  });

  proxy.end();
});

// Routes
app.use('/api/auth', require('./routes/authRoutes'));
app.use('/api/sensors', require('./routes/sensorRoutes'));
app.use('/api/equipment', require('./routes/equipmentRoutes'));
app.use('/api/stats', require('./routes/statsRoutes'));
app.use('/api/alerts', require('./routes/alertRoutes'));

// Global Error Handler (MUST be after all routes)
app.use((err, req, res, next) => {
  console.error('[Global Error Handler]', err.stack);
  res.status(err.status || 500).json({
    error: err.message || 'Internal Server Error',
    timestamp: new Date().toISOString()
  });
});

// 404 Handler
app.use((req, res) => {
  res.status(404).json({
    error: 'Route not found',
    path: req.url,
    method: req.method
  });
});

// Graceful Shutdown Handler
const gracefulShutdown = (signal) => {
  console.log(`\n[${signal}] Gracefully shutting down server...`);
  server.close(() => {
    console.log('[Shutdown] HTTP server closed');
    sequelize.close().then(() => {
      console.log('[Shutdown] Database connection closed');
      process.exit(0);
    });
  });

  // Force shutdown after 10 seconds
  setTimeout(() => {
    console.error('[Shutdown] Forcing shutdown after timeout');
    process.exit(1);
  }, 10000);
};

process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));

// Uncaught Exception Handler
process.on('uncaughtException', (err) => {
  console.error('[CRITICAL] Uncaught Exception:', err);
  gracefulShutdown('UNCAUGHT_EXCEPTION');
});

// Unhandled Promise Rejection Handler
process.on('unhandledRejection', (reason, promise) => {
  console.error('[CRITICAL] Unhandled Promise Rejection at:', promise, 'reason:', reason);
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`\n🚀 Server running on port ${PORT}`);
  console.log(`📱 Mobile/Web access: http://192.168.0.104:${PORT}`);
  console.log(`💻 Local access: http://localhost:${PORT}`);
  console.log(`\nWaiting for connections...\n`);
});
