from ultralytics import YOLO
import os
from pathlib import Path

if __name__ == '__main__':
    # Model and dataset paths
    model_path = r"C:\Users\harshal\Downloads\chack\runs\detect\train6\weights\best.pt"
    test_images_path = r"C:\Users\harshal\OneDrive\Desktop\snadroidapp\processed_yolo_dataset_2\processed_yolo_dataset\images\test"

    # Load the trained model
    print("Loading model...")
    model = YOLO(model_path)

    # Run inference on test dataset
    print(f"Running inference on test images from: {test_images_path}")
    results = model.predict(
        source=test_images_path,
        save=True,  # Save annotated images
        save_txt=True,  # Save results in txt format
        save_conf=True,  # Save confidence scores
        conf=0.25,  # Confidence threshold
        iou=0.45,  # IoU threshold for NMS
        project='test_results',  # Project folder
        name='run',  # Run name
        exist_ok=True  # Overwrite existing results
    )

    # Print summary
    print(f"\nInference completed!")
    print(f"Results saved in: test_results/run/")
    print(f"Total images processed: {len(results)}")

    # Display detection statistics
    total_detections = 0
    for r in results:
        total_detections += len(r.boxes)

    print(f"Total detections: {total_detections}")
    print(f"Average detections per image: {total_detections/len(results):.2f}")

    # Optional: Validate the model on test set (if dataset.yaml exists)
    data_yaml_path = r"C:\Users\harshal\OneDrive\Desktop\snadroidapp\processed_yolo_dataset_2\processed_yolo_dataset\dataset.yaml"
    if os.path.exists(data_yaml_path):
        print("\nRunning validation on test set...")
        metrics = model.val(
            data=data_yaml_path,
            split='test',
            workers=0  # Set workers to 0 to avoid multiprocessing issues on Windows
        )
        
        print(f"\nValidation Metrics:")
        print(f"mAP50: {metrics.box.map50:.4f}")
        print(f"mAP50-95: {metrics.box.map:.4f}")
        print(f"Precision: {metrics.box.mp:.4f}")
        print(f"Recall: {metrics.box.mr:.4f}")
    else:
        print(f"\nNote: dataset.yaml not found at {data_yaml_path}")
        print("Skipping validation. You can find annotated images in test_results/run/")