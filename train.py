from ultralytics import YOLO

if __name__ == '__main__':
    # Load a model
    model = YOLO('yolov8n.pt')
    
    # Train the model
    results = model.train(
        data='C:/Users/harshal/OneDrive/Desktop/snadroidapp/processed_yolo_dataset_2/processed_yolo_dataset/dataset.yaml',
        epochs=50,
        imgsz=640,
        device=0
    )