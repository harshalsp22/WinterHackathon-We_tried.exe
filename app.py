from flask import Flask, request, jsonify
from flask_cors import CORS
from ultralytics import YOLO
from PIL import Image
import io

app = Flask(__name__)
CORS(app)

# --- CONFIGURATION ---
MODEL_PATH = r"C:\Users\harshal\Downloads\chack\runs\detect\train6\weights\best.pt"
model = YOLO(MODEL_PATH)

@app.route('/detect', methods=['POST'])
def detect():
    if 'image' not in request.files:
        return jsonify({"success": False, "error": "No image provided"}), 400
    
    try:
        file = request.files['image']
        conf_val = float(request.form.get('confidence', 0.25))
        
        # Load image via PIL
        img_bytes = file.read()
        img = Image.open(io.BytesIO(img_bytes)).convert("RGB")
        
        # Run YOLO Inference
        results = model.predict(source=img, conf=conf_val, verbose=False)[0]
        
        detections = []
        for box in results.boxes:
            # Extract box coordinates as integers
            x1, y1, x2, y2 = map(int, box.xyxy[0].cpu().numpy())
            
            detections.append({
                "class_id": int(box.cls[0]),
                "class_name": "RAM Slot",  # Overriding label
                "confidence": round(float(box.conf[0]), 3),
                "bbox": {
                    "x1": x1, "y1": y1,
                    "x2": x2, "y2": y2,
                    "width": x2 - x1,
                    "height": y2 - y1
                }
            })
            
        return jsonify({
            "success": True,
            "detections_count": len(detections),
            "image_size": {
                "width": img.width,
                "height": img.height
            },
            "detections": detections
        })

    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

if __name__ == '__main__':
    print("🚀 RAM Slot Detection Server active on http://localhost:5000")
    app.run(host='0.0.0.0', port=5000)