from flask import Flask, Response, render_template_string
import cv2
import threading
import time
import urllib.parse
import os
from dotenv import load_dotenv
from datetime import datetime
import logging

app = Flask(__name__)

# Load environment variables from .env file
load_dotenv()

# Minimal logging
logging.basicConfig(level=logging.WARNING)

# Camera configuration - READ FROM ENV
CAMERA_CONFIG = {
    'ip': os.getenv('CAMERA_IP'),
    'port': os.getenv('CAMERA_PORT'),
    'username': os.getenv('CAMERA_USERNAME'),
    'password': os.getenv('CAMERA_PASSWORD'),
    'stream_path': os.getenv('CAMERA_STREAM_PATH')
}

# Performance settings for smooth streaming
STREAM_SETTINGS = {
    'frame_skip': 2,        # Process every 2nd frame
    'jpeg_quality': 70,     # Good balance of quality/speed
    'target_fps': 20        # Target frame rate
}

# Global variables
camera = None
camera_active = False
frame_data = None
frame_lock = threading.Lock()

class MinimalCamera:
    def __init__(self, config):
        self.config = config
        self.cap = None
        self.running = False
        self.frame_count = 0
        self.skip_counter = 0
        
    def build_camera_url(self):
        """Build the RTSP camera URL"""
        ip = self.config['ip']
        port = self.config['port']
        username = self.config['username']
        password = self.config['password']
        path = self.config['stream_path']
        
        return f"rtsp://{username}:{password}@{ip}:{port}{path}"
    
    def connect_and_start(self):
        """Connect to camera and start streaming"""
        try:
            camera_url = self.build_camera_url()
            print(f"Connecting to camera: {camera_url.replace(self.config['password'], '*****')}")
            
            # Create VideoCapture with optimized settings
            self.cap = cv2.VideoCapture(camera_url, cv2.CAP_FFMPEG)
            
            # Optimize for streaming
            self.cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
            self.cap.set(cv2.CAP_PROP_FPS, STREAM_SETTINGS['target_fps'])
            
            if self.cap.isOpened():
                # Test connection
                ret, test_frame = self.cap.read()
                if ret and test_frame is not None:
                    print(f"Camera connected successfully: {test_frame.shape}")
                    
                    # Start streaming thread
                    self.running = True
                    self.stream_thread = threading.Thread(target=self._stream_loop, daemon=True)
                    self.stream_thread.start()
                    return True
                else:
                    print("Failed to read frames from camera")
                    return False
            else:
                print("Failed to connect to camera")
                return False
                
        except Exception as e:
            print(f"Camera connection error: {e}")
            return False
    
    def _stream_loop(self):
        """Main streaming loop"""
        global frame_data
        
        print("Starting video stream...")
        
        while self.running and self.cap and self.cap.isOpened():
            try:
                ret, frame = self.cap.read()
                
                if ret and frame is not None:
                    self.frame_count += 1
                    
                    # Frame skipping for performance
                    self.skip_counter += 1
                    if self.skip_counter % STREAM_SETTINGS['frame_skip'] != 0:
                        continue
                    
                    # Encode frame
                    encode_params = [int(cv2.IMWRITE_JPEG_QUALITY), STREAM_SETTINGS['jpeg_quality']]
                    ret, buffer = cv2.imencode('.jpg', frame, encode_params)
                    
                    if ret:
                        with frame_lock:
                            frame_data = buffer.tobytes()
                else:
                    time.sleep(0.01)
                    
            except Exception as e:
                print(f"Streaming error: {e}")
                time.sleep(0.1)
        
        print("Video stream ended")
    
    def stop(self):
        """Stop streaming"""
        self.running = False
        if self.cap:
            self.cap.release()

# Initialize and start camera
camera = MinimalCamera(CAMERA_CONFIG)

@app.route('/')
def index():
    """Main page with just video stream"""
    return render_template_string(MINIMAL_TEMPLATE)

@app.route('/video_feed')
def video_feed():
    """Direct video streaming endpoint"""
    def generate():
        global frame_data
        
        while True:
            try:
                with frame_lock:
                    current_frame = frame_data
                
                if current_frame is not None:
                    yield (b'--frame\r\n'
                           b'Content-Type: image/jpeg\r\n'
                           b'Content-Length: ' + str(len(current_frame)).encode() + b'\r\n\r\n' + 
                           current_frame + b'\r\n')
                else:
                    # Simple placeholder when no video
                    placeholder = create_placeholder()
                    yield (b'--frame\r\n'
                           b'Content-Type: image/jpeg\r\n\r\n' + placeholder + b'\r\n')
                
                time.sleep(0.05)  # ~20 FPS
                
            except Exception as e:
                print(f"Video feed error: {e}")
                time.sleep(0.1)
    
    return Response(generate(),
                    mimetype='multipart/x-mixed-replace; boundary=frame',
                    headers={
                        'Cache-Control': 'no-cache, no-store, must-revalidate',
                        'Pragma': 'no-cache',
                        'Expires': '0'
                    })

def create_placeholder():
    """Simple placeholder frame"""
    import numpy as np
    
    frame = np.zeros((480, 640, 3), dtype=np.uint8)
    frame[:, :] = [40, 40, 40]  # Dark gray
    
    # Simple text
    font = cv2.FONT_HERSHEY_SIMPLEX
    cv2.putText(frame, "CONNECTING TO CAMERA...", (150, 240), font, 0.8, (255, 255, 255), 2)
    
    ret, buffer = cv2.imencode('.jpg', frame, [cv2.IMWRITE_JPEG_QUALITY, 70])
    return buffer.tobytes() if ret else b''

# Minimal HTML template
MINIMAL_TEMPLATE = '''<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Video Stream</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            background: #000;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            font-family: Arial, sans-serif;
        }
        
        .video-container {
            position: relative;
            width: 90vw;
            max-width: 1200px;
            background: #000;
            border-radius: 8px;
            overflow: hidden;
            box-shadow: 0 4px 20px rgba(0,0,0,0.5);
        }
        
        .video-stream {
            width: 100%;
            height: auto;
            display: block;
            object-fit: contain;
        }
        
        .fullscreen-btn {
            position: absolute;
            bottom: 15px;
            right: 15px;
            background: rgba(0, 0, 0, 0.7);
            color: white;
            border: none;
            padding: 10px 15px;
            border-radius: 6px;
            cursor: pointer;
            font-size: 12px;
            font-weight: 600;
            backdrop-filter: blur(10px);
            transition: all 0.3s ease;
            opacity: 0;
            z-index: 10;
        }
        
        .video-container:hover .fullscreen-btn {
            opacity: 1;
        }
        
        .fullscreen-btn:hover {
            background: rgba(0, 0, 0, 0.9);
            transform: scale(1.05);
        }
        
        /* Fullscreen styles */
        .video-container:-webkit-full-screen {
            width: 100vw;
            height: 100vh;
            max-width: none;
        }
        
        .video-container:-moz-full-screen {
            width: 100vw;
            height: 100vh;
            max-width: none;
        }
        
        .video-container:fullscreen {
            width: 100vw;
            height: 100vh;
            max-width: none;
        }
        
        .video-container:fullscreen .video-stream {
            height: 100vh;
            object-fit: cover;
        }
        
        @media (max-width: 768px) {
            .video-container {
                width: 95vw;
            }
        }
    </style>
</head>
<body>
    <div class="video-container" id="video-container">
        <img id="video-stream" class="video-stream" src="/video_feed" alt="Live Video Stream">
        <button class="fullscreen-btn" onclick="toggleFullscreen()">⛶ FULLSCREEN</button>
    </div>

    <script>
        function toggleFullscreen() {
            const container = document.getElementById('video-container');
            
            if (document.fullscreenElement) {
                document.exitFullscreen();
            } else {
                container.requestFullscreen().catch(err => {
                    console.error('Fullscreen error:', err);
                });
            }
        }

        // Double-click for fullscreen
        document.getElementById('video-stream').addEventListener('dblclick', toggleFullscreen);

        // Auto-refresh on error
        document.getElementById('video-stream').addEventListener('error', function() {
            console.log('Video stream error, refreshing...');
            setTimeout(() => {
                this.src = '/video_feed?' + Date.now();
            }, 2000);
        });

        // Keyboard shortcut for fullscreen (F key)
        document.addEventListener('keydown', function(event) {
            if (event.key === 'f' || event.key === 'F') {
                toggleFullscreen();
            }
        });

        console.log('Direct video stream ready');
    </script>
</body>
</html>'''

if __name__ == '__main__':
    print("Starting Direct Video Stream Server...")
    print("=" * 50)
    print(f"Camera IP: {CAMERA_CONFIG['ip']}")
    print(f"Stream URL: rtsp://{CAMERA_CONFIG['username']}:***@{CAMERA_CONFIG['ip']}:{CAMERA_CONFIG['port']}{CAMERA_CONFIG['stream_path']}")
    print("Web Access: http://localhost:5000")
    print("=" * 50)
    
    # Start camera before Flask app
    if camera.connect_and_start():
        print("Camera connected, starting web server...")
        camera_active = True
    else:
        print("Warning: Camera connection failed, starting server anyway...")
    
    try:
        app.run(host='0.0.0.0', port=5000, debug=False, threaded=True)
    except KeyboardInterrupt:
        print("\nShutting down...")
        if camera:
            camera.stop()
        print("Server stopped")