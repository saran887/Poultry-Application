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

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
  }
});

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
io.on('connection', (socket) => {
  console.log(`\n[Socket] New client connected: ${socket.id}`);
  
  socket.on('disconnect', () => {
    console.log(`[Socket] Client disconnected: ${socket.id}`);
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

// Ingestion Logic: Random values every 5 minutes
const startIngestion = () => {
  const insertData = async () => {
    try {
      const now = new Date();
      now.setMilliseconds(0);
      
      const records = [
        { device_id: 1, value: parseFloat((20 + Math.random() * 15).toFixed(2)), recorded_at: now },
        { device_id: 2, value: parseFloat((40 + Math.random() * 40).toFixed(2)), recorded_at: now },
        { device_id: 3, value: parseFloat((10 + Math.random() * 90).toFixed(2)), recorded_at: now }
      ];
      
      await FarmOverview.bulkCreate(records);
      console.log(`[Ingestion] Data inserted for ${now.toISOString()}`);
      
      // Emit sensor update via Socket.io
      const sensorData = {
        temperature: records[0].value,
        humidity: records[1].value,
        waterLevel: records[2].value,
        timestamp: now
      };
      io.emit('sensorUpdate', sensorData);
    } catch (err) {
      console.error('[Ingestion Error]', err.message);
    }
  };

  // Run immediately then every 5 mins
  insertData();
  setInterval(insertData, 5 * 60 * 1000);
};

// Start Python Camera Stream Server
const startPythonStream = () => {
  const pythonPath = process.platform === 'win32' ? 'D:\\Python\\python.exe' : 'python3';
  const scriptPath = path.join(__dirname, 'directstream_ipcamera.py');
  
  console.log(`[Python] Starting stream server using: ${pythonPath}`);
  console.log(`[Python] Script: ${scriptPath}`);
  
  const pythonProcess = spawn(pythonPath, [scriptPath], {
    stdio: 'inherit',
    env: process.env
  });

  pythonProcess.on('error', (err) => {
    console.error('[Python Error] Failed to start Python process:', err.message);
    console.log('TIP: Check if python is installed at D:\\Python\\python.exe or update index.js');
  });

  pythonProcess.on('close', (code) => {
    console.log(`[Python] Process exited with code ${code}`);
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
  })
  .catch((err) => console.error('PostgreSQL connection error:', err));

// Routes
app.use('/api/auth', require('./routes/authRoutes'));
app.use('/api/sensors', require('./routes/sensorRoutes'));
app.use('/api/equipment', require('./routes/equipmentRoutes'));
app.use('/api/stats', require('./routes/statsRoutes'));
app.use('/api/alerts', require('./routes/alertRoutes'));

server.listen(PORT, '0.0.0.0', () => {
  console.log(`\n🚀 Server running on port ${PORT}`);
  console.log(`📱 Mobile/Web access: http://192.168.0.104:${PORT}`);
  console.log(`💻 Local access: http://localhost:${PORT}`);
  console.log(`\nWaiting for connections...\n`);
});
