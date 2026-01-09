import cv2
import threading
import time
import os
import base64
import sys
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Camera configuration
CAMERA_CONFIG = {
    'ip': os.getenv('CAMERA_IP'),
    'port': os.getenv('CAMERA_PORT'),
    'username': os.getenv('CAMERA_USERNAME'),
    'password': os.getenv('CAMERA_PASSWORD'),
    'stream_path': os.getenv('CAMERA_STREAM_PATH')
}

class WebSocketCamera:
    def __init__(self, config):
        self.config = config
        self.cap = None
        self.running = False
        
    def build_camera_url(self):
        return f"rtsp://{self.config['username']}:{self.config['password']}@{self.config['ip']}:{self.config['port']}{self.config['stream_path']}"
    
    def start(self):
        camera_url = self.build_camera_url()
        # Use FFMPEG for faster RTSP processing
        self.cap = cv2.VideoCapture(camera_url, cv2.CAP_FFMPEG)
        self.cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
        
        if self.cap.isOpened():
            self.running = True
            while self.running:
                ret, frame = self.cap.read()
                if not ret:
                    time.sleep(0.1)
                    continue
                
                # Resize for performance if needed (optional)
                # frame = cv2.resize(frame, (640, 360))
                
                # Encode as JPEG
                _, buffer = cv2.imencode('.jpg', frame, [cv2.IMWRITE_JPEG_QUALITY, 60])
                
                # Convert to Base64
                jpg_as_text = base64.b64encode(buffer).decode('utf-8')
                
                # Write to stdout with a clear delimiter
                sys.stdout.write(f"FRAME_START{jpg_as_text}FRAME_END\n")
                sys.stdout.flush()
                
                # Control FPS (e.g., ~20 FPS)
                time.sleep(0.05)
        else:
            print("ERROR: Could not open camera")

if __name__ == '__main__':
    cam = WebSocketCamera(CAMERA_CONFIG)
    try:
        cam.start()
    except KeyboardInterrupt:
        cam.running = False
        if cam.cap:
            cam.cap.release()