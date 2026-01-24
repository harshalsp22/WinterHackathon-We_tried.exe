from flask import Flask, request, jsonify
from flask_cors import CORS
import cv2
import numpy as np
from ultralytics import YOLO

app = Flask(__name__)
CORS(app)

# --- CONFIGURATION ---
MODEL_PATH = r"C:\Users\harshal\Downloads\chack\runs\detect\train6\weights\best.pt"
model = YOLO(MODEL_PATH)

@app.route('/', methods=['GET'])
def home():
    return jsonify({"status": "ok", "app": "RAM Slot Detection API"})

@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "ok", "model_loaded": model is not None})

@app.route('/detect', methods=['POST'])
def detect():
    if 'image' not in request.files:
        return jsonify({"success": False, "error": "No image"}), 400
    
    try:
        file = request.files['image']
        # Defaulting to 0.15 as requested for higher sensitivity
        confidence = float(request.form.get('confidence', 0.15))
        
        # Read image using OpenCV
        img_bytes = file.read()
        nparr = np.frombuffer(img_bytes, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        
        if img is None:
            return jsonify({"success": False, "error": "Invalid image"}), 400
        
        # Run YOLO
        results = model(img, conf=confidence)
        
        detections = []
        for result in results:
            for box in result.boxes:
                x1, y1, x2, y2 = box.xyxy[0].tolist()
                
                detections.append({
                    "class_name": "RAM Slot", # Custom Label
                    "confidence": round(float(box.conf[0]), 3),
                    "bbox": {
                        "x1": int(x1),
                        "y1": int(y1),
                        "x2": int(x2),
                        "y2": int(y2),
                        "width": int(x2 - x1),
                        "height": int(y2 - y1)
                    }
                })
        
        return jsonify({
            "success": True,
            "detections_count": len(detections),
            "image_size": {
                "width": img.shape[1],
                "height": img.shape[0]
            },
            "detections": detections
        })
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

if __name__ == '__main__':
    print("Server starting on http://localhost:5000")
    app.run(host='0.0.0.0', port=5000, debug=True)
