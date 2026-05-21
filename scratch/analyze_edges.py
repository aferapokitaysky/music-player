import os
import numpy as np
from PIL import Image, ImageDraw

def main():
    src_path = "/Users/korova/.gemini/antigravity-ide/brain/f7539277-1b6f-4f20-922d-7eb6d02f65d9/aferapokitaysky_logo_1779284571354.png"
    
    if not os.path.exists(src_path):
        print(f"Source file not found: {src_path}")
        return
        
    img = Image.open(src_path).convert("L") # load as grayscale
    arr = np.array(img, dtype=float)
    h, w = arr.shape
    
    # Calculate gradient along horizontal and vertical directions
    grad_x = np.abs(np.diff(arr, axis=1))
    grad_y = np.abs(np.diff(arr, axis=0))
    
    # Let's sum the gradients along the vertical and horizontal axes to find the boundaries of the main circle/squircle
    sum_x = np.sum(grad_x, axis=0) # shape (w-1,)
    sum_y = np.sum(grad_y, axis=1) # shape (h-1,)
    
    # The edges of the squircle will show up as large spikes in sum_x and sum_y.
    # Let's find the first and last columns/rows where the gradient sum is above a certain percentage of the max.
    threshold_x = np.max(sum_x) * 0.3
    threshold_y = np.max(sum_y) * 0.3
    
    left = np.where(sum_x > threshold_x)[0][0]
    right = np.where(sum_x > threshold_x)[0][-1] + 1
    top = np.where(sum_y > threshold_y)[0][0]
    bottom = np.where(sum_y > threshold_y)[0][-1] + 1
    
    print(f"Detected sharp edges: Left={left}, Right={right}, Top={top}, Bottom={bottom}")
    
    # Center of the detected edges
    cx = (left + right) / 2.0
    cy = (top + bottom) / 2.0
    width_detected = right - left
    height_detected = bottom - top
    size = min(width_detected, height_detected)
    
    print(f"Calculated squircle - Center: ({cx}, {cy}), Size: {size}")

if __name__ == "__main__":
    main()
