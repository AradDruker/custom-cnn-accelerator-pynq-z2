from flask import Flask, render_template, request, jsonify
import cv2, numpy as np, base64, os, re, requests, json
import matplotlib; matplotlib.use('Agg')
import matplotlib.pyplot as plt
from sympy import lambdify
import sympy as sp
from datetime import datetime
from sympy.parsing.sympy_parser import parse_expr, standard_transformations, implicit_multiplication_application

app = Flask(__name__)

# Configuration settings
APP_CONFIG = {
    'send_images_to_endpoint': True,  # Set to False to disable sending images
    'endpoint_url': "http://192.168.1.99:5000/upload"  # Endpoint URL for sending images
}

# Global variable to store the latest prediction from PYNQ
LATEST_PREDICTION = None

# Ensure required directories exist
os.makedirs('static/debug_images', exist_ok=True)
os.makedirs('data', exist_ok=True)  # Folder to store all 28x28 character images

# Ensure feedback directory exists
FEEDBACK_DIR = 'feedback'
os.makedirs(FEEDBACK_DIR, exist_ok=True)
FEEDBACK_FILE = os.path.join(FEEDBACK_DIR, 'recognition_feedback.json')

# Initialize feedback file if it doesn't exist
if not os.path.exists(FEEDBACK_FILE):
    with open(FEEDBACK_FILE, 'w') as f:
        json.dump({
            'feedback_entries': [],
            'stats': {
                'total': 0,
                'correct': 0,
                'incorrect': 0,
                'accuracy': 0
            }
        }, f, indent=2)

def clear_debug_images():
    """Clear previous debug images from the static/debug_images directory"""
    debug_dir = 'static/debug_images'

    for filename in os.listdir(debug_dir):
        file_path = os.path.join(debug_dir, filename)
        if os.path.isfile(file_path):
            os.remove(file_path)

def send_images_to_endpoint(image_paths, endpoint_url):
    try:
        files = [
            ('file', (os.path.basename(p), open(p, 'rb'), 'image/png'))
            for p in image_paths
        ]
        resp = requests.post(endpoint_url, files=files, timeout=10)
        resp.raise_for_status()
        
        # Try to parse JSON response
        try:
            return resp.json() 
        except json.JSONDecodeError as je:
            # If we can't decode JSON, return the text content instead
            print(f"[CLIENT] Warning: Could not parse JSON response: {je}")
            return {"text": resp.text.strip(), "raw_response": True}
    except Exception as e:
        print(f"[CLIENT] Failed to send images: {e}")
        return {"error": str(e)}
    finally:
        # Ensure all file handles are closed
        for f in files:
            try:
                f[1][1].close()
            except:
                pass

@app.route('/')
def index():
    return render_template('index.html', APP_CONFIG=APP_CONFIG)

def count_data_images():
    """Count the total number of character images in the data folder"""
    try:
        return len([f for f in os.listdir('data') if f.endswith('.png')])
    except Exception as e:
        print(f"Error counting data images: {e}")
        return 0

@app.route('/process_equation', methods=['POST'])
def process_equation():
    global LATEST_PREDICTION
    # Clear previous debug images
    clear_debug_images()
    
    data = request.json
    image_data = data['image'].split(',')[1]
    is_mock = data.get('mock', False)
    mock_equation = data.get('mockEquation', " ")
    
    # Generate a timestamp for filenames
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S_%f")
    
    # Decode the base64 image
    img_bytes = base64.b64decode(image_data)
    img_arr = np.frombuffer(img_bytes, np.uint8)
    img = cv2.imdecode(img_arr, cv2.IMREAD_GRAYSCALE)
    
    # Save the original image for debugging
    cv2.imwrite('static/debug_images/original.png', img)
    original_image_path = 'static/debug_images/original.png'
    
    # Process the image to extract characters
    char_images = []
    char_positions = []
    if isinstance(img, np.ndarray) and img.size > 0:
        char_images, char_positions = extract_characters(img)
    
    # Only include character images in the response
    debug_image_paths = []
    # We'll still save the diagnostic images to disk but won't include them in the response
    
    # Endpoint URL for sending the images
    endpoint_url = APP_CONFIG['endpoint_url']
    
    for i, char_img in enumerate(char_images):
        # Use sequential numbers instead of char_X naming for debug images
        debug_path = f'static/debug_images/{i+1:02d}.png'
        cv2.imwrite(debug_path, char_img)
        debug_image_paths.append(debug_path)
        
        # Save to data folder with timestamp to ensure uniqueness
        data_path = f'data/char_{timestamp}_{i+1}.png'
        inverted_img = cv2.bitwise_not(char_img)
        cv2.imwrite(data_path, inverted_img)
    
    response_data = None
    # Only send to server if not in mock mode
    if not is_mock and APP_CONFIG['send_images_to_endpoint'] and debug_image_paths:
        response_data = send_images_to_endpoint(debug_image_paths, endpoint_url)
        print(f"[CLIENT] API response: {response_data}")
    
    if is_mock:
        equation = mock_equation
    elif LATEST_PREDICTION and not is_mock:
        # Use the stored prediction from the PYNQ device if available and mock is disabled
        equation = LATEST_PREDICTION
        # Reset prediction after using it
        LATEST_PREDICTION = None
    elif response_data and 'text' in response_data:
        equation = response_data['text']
        # Clean up possible formatting issues in the equation
        equation = equation.replace('\n', '').replace('\r', '').strip()
    elif response_data and 'error' in response_data:
        # Handle error case
        print(f"[CLIENT] Error in API response: {response_data['error']}")
        equation = " "  # Fallback on error
    else:
        equation = " "
    
    # Remove duplicate equals signs that can arise if the '=' glyph was split into
    # two separate strokes ("= =" or "==") by the recognition pipeline.
    equation = re.sub(r'=\s*=+', '=', equation)
    
    # Process positional information for superscripts/exponents
    if char_positions and not is_mock and response_data:
        # If we have position data and a response from the recognition service
        equation = detect_and_apply_exponents(equation, char_positions)
    
    # Combine adjacent numbers that are separated by spaces (e.g., "3 4" -> "34")
    # Keep applying until no more changes (handles cases like "3 4 5" -> "345")
    prev_equation = ""
    while prev_equation != equation:
        prev_equation = equation
        equation = re.sub(r'(\d+)\s+(\d+)', r'\1\2', equation)
    
    # Remove spaces between numbers and variables (e.g., "4 x" -> "4x")
    equation = re.sub(r'(\d+)\s+([a-zA-Z])', r'\1\2', equation)
    
    # Ensure proper spacing around operators
    # First add spaces around all operators
    equation = re.sub(r'([+\-*/^=])', r' \1 ', equation)
    # Then remove double spaces
    equation = re.sub(r'\s+', ' ', equation).strip()
    
    # Ensure negative signs are properly handled (e.g., "y = - 3x" -> "y = -3x")
    equation = re.sub(r'(\s+)-\s+(\d+)', r'\1-\2', equation)
    
    # Ensure exponents with ^ are properly formatted (e.g., "x ^ 2" -> "x^2")
    equation = re.sub(r'([a-zA-Z0-9])\s+\^\s+(\d+)', r'\1^\2', equation)
    
    # Store the processed equation for display (without explicit multiplication)
    display_equation = equation
    
    # For internal calculation, add explicit multiplication between coefficients and variables
    calculation_equation = re.sub(r'(\d+)([a-zA-Z])', r'\1*\2', display_equation)
        
    # Generate plot
    plot_path = generate_plot(calculation_equation)
    
    # Count the total number of character images in the data folder
    total_data_images = count_data_images()
    
    return jsonify({
        'equation': display_equation, 
        'plot': plot_path,
        'debug_images': debug_image_paths,
        'total_data_images': total_data_images
    })

def extract_characters(img):
    """
    Extract individual character images and their positional metadata from the
    provided grayscale image.  This implementation is based on connected
    component analysis instead of a naïve column scan.  The previous column
    scan tended to merge characters that shared the same x-range (for
    instance a superscript that is slightly to the right of the base letter),
    which in turn prevented reliable exponent detection.  Using connected
    components guarantees that spatially disconnected blobs – even if they
    share columns – are treated as separate characters.
    """

    # 1. Binarise and invert so that foreground is 1, background is 0
    _, binary_inv = cv2.threshold(img, 180, 255, cv2.THRESH_BINARY_INV)
    
    # Apply dilation to thicken thin strokes for component detection
    kernel = np.ones((2,2), np.uint8)  # Adjust kernel size as needed for desired thickness
    binary_inv = cv2.dilate(binary_inv, kernel, iterations=1)
    
    cv2.imwrite('static/debug_images/binary_for_scan.png', binary_inv)

    height, width = binary_inv.shape

    # 2. Connected component analysis (8-way connectivity)
    num_labels, labels, stats, centroids = cv2.connectedComponentsWithStats(
        binary_inv, connectivity=8)

    char_images = []
    char_positions = []

    # For visual inspection – draw bounding boxes
    debug_boxes_img = cv2.cvtColor(img.copy(), cv2.COLOR_GRAY2BGR)

    # Collect component bounding boxes, skip background (label 0)
    components = []
    for label in range(1, num_labels):
        x, y, w, h, area = stats[label]

        # Filter out tiny components / noise
        if area < 20:  # heuristic threshold – tweak if necessary
            continue

        components.append((x, y, w, h, label))

    # Sort left-to-right so the order matches reading direction
    components.sort(key=lambda c: c[0])

    # --- Heuristic merge for '=' sign (two parallel horizontal bars) ---------
    merged_components = []
    i = 0
    while i < len(components):
        x1, y1, w1, h1, label1 = components[i]

        # Height-to-width ratio for a typical stroke of '=' is very small
        # Check if this component looks like a horizontal bar
        is_small_bar_1 = h1 < w1 * 0.6  # More permissive ratio to catch thicker bars

        # Look ahead to see if next component forms the second bar
        if i + 1 < len(components):
            x2, y2, w2, h2, label2 = components[i + 1]

            # Calculate horizontal overlap percentage
            horiz_overlap = min(x1 + w1, x2 + w2) - max(x1, x2)
            # Avoid division by zero
            min_width = min(w1, w2)
            if min_width > 0:
                horiz_overlap_percent = horiz_overlap / min_width
            else:
                horiz_overlap_percent = 0
            
            # More relaxed width similarity check
            widths_similar = abs(w1 - w2) < 0.5 * max(w1, w2)  # Much more lenient
            is_small_bar_2 = h2 < w2 * 0.6  # More permissive ratio
            
            # Calculate vertical positioning metrics
            center_y1 = y1 + h1 // 2
            center_y2 = y2 + h2 // 2
            vertical_gap = abs(center_y1 - center_y2)
            
            # Require reasonable vertical proximity (bars stacked, not far apart)
            stacked = vertical_gap < max(h1, h2) * 5  # Even more generous allowance
            
            # Improved equals sign detection with more relaxed conditions
            # At least ensure both are horizontal bars with some overlap
            if (is_small_bar_1 and is_small_bar_2 and 
                horiz_overlap_percent > 0.3 and  # Reduced overlap requirement
                widths_similar and stacked):

                # Merge into one component representing '='
                x_merge = min(x1, x2)
                y_merge = min(y1, y2)
                right_merge = max(x1 + w1, x2 + w2)
                bottom_merge = max(y1 + h1, y2 + h2)
                w_merge = right_merge - x_merge
                h_merge = bottom_merge - y_merge

                merged_components.append((x_merge, y_merge, w_merge, h_merge, None))
                i += 2  # Skip the next component as it's merged
                continue

        # If not merged, append the current component as is
        merged_components.append((x1, y1, w1, h1, label1))
        i += 1

    # Replace components list with merged version
    components = merged_components

    # Padding values (tuned empirically – same as previous implementation)
    h_padding = 15
    v_padding = 10  # generous vertical padding to keep superscripts intact
    
    # Define a smaller kernel for the final character images
    char_kernel = np.ones((2, 2), np.uint8)

    for x, y, w, h, label in components:
        # Bounding box with padding (clipped to image bounds)
        x_start = max(0, x - h_padding)
        y_start = max(0, y - v_padding)
        x_end = min(width, x + w + h_padding)
        y_end = min(height, y + h + v_padding)

        # Draw rectangle for debugging
        cv2.rectangle(debug_boxes_img, (x_start, y_start), (x_end - 1, y_end - 1), (0, 0, 255), 1)

        # Crop, centre on square canvas, and threshold to pure black/white
        char_img = img[y_start:y_end, x_start:x_end]
        if char_img.size == 0:
            continue

        h_char, w_char = char_img.shape
        max_dim = max(h_char, w_char)
        square_img = np.full((max_dim, max_dim), 255, dtype=np.uint8)
        y_offset = (max_dim - h_char) // 2
        x_offset = (max_dim - w_char) // 2
        square_img[y_offset:y_offset + h_char, x_offset:x_offset + w_char] = char_img

        # Re-binarise to remove anti-aliased grey values
        _, final_img = cv2.threshold(square_img, 245, 255, cv2.THRESH_BINARY)
        
        # Invert for dilation (black on white → white on black)
        final_img_inv = cv2.bitwise_not(final_img)
        
        # Apply dilation to thicken strokes in the final character image
        final_img_inv = cv2.dilate(final_img_inv, char_kernel, iterations=2)
        
        # Invert back (white on black → black on white)
        final_img = cv2.bitwise_not(final_img_inv)

        char_images.append(final_img)

        # Positional metadata (centroid & bbox)
        char_positions.append({
            'x': x + w // 2,
            'y': y + h // 2,
            'width': w,
            'height': h,
            'top': y,
            'bottom': y + h,
            'left': x,
            'right': x + w
        })

    # Save debug image
    cv2.imwrite('static/debug_images/boxes_connected_components.png', debug_boxes_img)

    return char_images, char_positions

def detect_and_apply_exponents(equation, char_positions):
    """
    Detects when characters are positioned as exponents (superscripts)
    and modifies the equation string accordingly.
    Only applies to the right side of the equation (after the equals sign).
    Groups all consecutive superscripted characters at the same height as the first exponent.
    """
    if '=' not in equation:
        return equation

    left_side, right_side = equation.split('=', 1)
    left_chars = list(left_side.replace(" ", ""))
    right_chars = list(right_side.replace(" ", ""))
    left_side_length = len(left_side.replace(" ", ""))
    right_start_idx = left_side_length + 1  # +1 for the equals sign
    if len(char_positions) < right_start_idx + len(right_chars):
        print("[WARNING] Character count mismatch with position data. Skipping exponent detection.")
        return equation
    right_positions = char_positions[right_start_idx:]
    if len(right_chars) != len(right_positions):
        print("[WARNING] Right side character count mismatch. Skipping exponent detection.")
        return equation

    new_right = []
    i = 0
    while i < len(right_chars):
        base_char = right_chars[i]
        base_pos = right_positions[i]
        j = i + 1
        # Special handling: if next char is '-', check the char after minus for superscript
        if j < len(right_chars) and right_chars[j] == '-':
            if j + 1 < len(right_chars):
                exp_pos = right_positions[j + 1]
                horiz_condition = exp_pos['left'] >= base_pos['left'] + base_pos['width'] * 0.3
                vert_condition = exp_pos['bottom'] <= base_pos['top'] + base_pos['height'] * 0.6
                if horiz_condition and vert_condition:
                    # Start exponent group: minus + next char(s) at same height
                    new_right.append(base_char)
                    new_right.append('^')
                    exp_group = ['-', right_chars[j + 1]]
                    first_exp_bottom = exp_pos['bottom']
                    k = j + 2
                    while k < len(right_chars):
                        next_exp_pos = right_positions[k]
                        tolerance = max(8, int(base_pos['height'] * 0.3))
                        if next_exp_pos['bottom'] <= first_exp_bottom + tolerance:
                            exp_group.append(right_chars[k])
                            k += 1
                        else:
                            break
                    if len(exp_group) > 1:
                        new_right.append('(')
                        new_right.extend(exp_group)
                        new_right.append(')')
                    else:
                        new_right.extend(exp_group)
                    i = k
                    continue
        # Original logic for normal superscript
        if j < len(right_chars):
            exp_pos = right_positions[j]
            horiz_condition = exp_pos['left'] >= base_pos['left'] + base_pos['width'] * 0.3
            vert_condition = exp_pos['bottom'] <= base_pos['top'] + base_pos['height'] * 0.6
            if horiz_condition and vert_condition:
                # Start exponent group
                new_right.append(base_char)
                new_right.append('^')
                exp_group = []
                first_exp_bottom = exp_pos['bottom']
                while j < len(right_chars):
                    exp_pos = right_positions[j]
                    tolerance = max(8, int(base_pos['height'] * 0.3))
                    if exp_pos['bottom'] <= first_exp_bottom + tolerance:
                        exp_group.append(right_chars[j])
                        j += 1
                    else:
                        break
                if len(exp_group) > 1:
                    new_right.append('(')
                    new_right.extend(exp_group)
                    new_right.append(')')
                else:
                    new_right.extend(exp_group)
                i = j
                continue
        # Not an exponent, just add normally
        new_right.append(base_char)
        i += 1
    modified_right_side = ''.join(new_right)
    modified_equation = left_side + "=" + modified_right_side
    modified_equation = re.sub(r'([^=])=([^=])', r'\1 = \2', modified_equation)

    return modified_equation

def generate_plot(equation):
    try:
        print(f"Starting to generate plot for equation: {equation}")
        
        # Make a copy of the original equation for display purposes
        display_equation = equation
        
        # Split equation by equals sign
        parts = equation.split('=')
        if len(parts) != 2:
            print(f"Error: Invalid equation format, needs an equals sign: {equation}")
            return None
        
        left_side = parts[0].strip()
        right_side = parts[1].strip()
                
        # Determine the variable names
        # Left side is the dependent variable (y-axis)
        y_var = left_side if len(left_side) == 1 else 'y'  # Use single letter variable or default to 'y'
        
        # Determine independent variable (x-axis) from the right side
        # Default to 'x' if we can't find another variable
        x_var = 'x'
                
        # Try direct numerical evaluation for non-pi constants
        if x_var not in right_side:
            try:
                constant = float(right_side)
                
                # Generate horizontal line
                x_vals = np.linspace(-10, 10, 2)
                y_vals = np.full_like(x_vals, constant)
                
                # Create a wider canvas with a narrower plot area
                plt.figure(figsize=(14, 6), dpi=100)  # Increased width even more
                plt.plot(x_vals, y_vals, 'b-', linewidth=1.5)
                plt.axhline(y=0, color='k', linestyle='-', alpha=0.3)
                plt.axvline(x=0, color='k', linestyle='-', alpha=0.3)
                plt.grid(True, alpha=0.3)
                plt.xlabel(x_var)
                plt.ylabel(y_var)
                
                # # Make the plot area narrower by adjusting margins
                # plt.subplots_adjust(left=0.25, right=0.75)  # Add more space on left and right
                
                plot_path = 'static/debug_images/plot.png'
                plt.savefig(plot_path, bbox_inches='tight', pad_inches=0.3)
                plt.close()
                
                return plot_path
            except ValueError:
                print(f"Not a simple numeric constant: {right_side}")
                # Continue with other parsing methods
        
        # Default to using sympy for all other cases
        return plot_with_sympy(equation, display_equation, x_var, y_var)
            
    except Exception as e:
        print(f"General error in plot generation: {e}")
        import traceback
        traceback.print_exc()
        
    # If we reach here, plotting failed
    return None

def contains_x_pow_nonint(expr, x_var):
    # Recursively check if any Pow node has x as the base and a non-integer or variable exponent
    if isinstance(expr, sp.Pow):
        base, exp = expr.args
        if base == sp.Symbol(x_var):
            # If exponent is a constant integer (Python int, float with integer value, or SymPy Integer)
            if (
                isinstance(exp, int)
                or (isinstance(exp, float) and exp.is_integer())
                or (hasattr(exp, 'is_integer') and exp.is_integer and exp.is_number)
            ):
                return False
            else:
                return True
    for arg in getattr(expr, 'args', []):
        if contains_x_pow_nonint(arg, x_var):
            return True
    return False

def plot_with_sympy(equation, display_equation, x_var, y_var):
    """
    Helper function to handle plotting with sympy for non-constant expressions
    Sets x-range based on the mathematical domain of the expression.
    Plots only where the function is real and finite.
    """
    try:
        # Split equation by equals sign
        parts = equation.split('=')
        right_side = parts[1].strip()
        # Ensure negative exponents (including -3x, -2.5x, -x, etc.) are wrapped in parentheses
        right_side = re.sub(r'(\^|\*\*)\s*(-[a-zA-Z0-9.]+)', r'\1(\2)', right_side)
        right_side_normalized = right_side.replace('^', '**')
        sym_var = sp.symbols(x_var)
        transformations = (standard_transformations + (implicit_multiplication_application,))
        expr = parse_expr(right_side_normalized.replace('pi', 'sp.pi'), transformations=transformations, local_dict={"sp": sp, x_var: sym_var})
        # Robustly restrict x domain if x is in the base of a power with non-integer exponent
        restrict_positive_x = contains_x_pow_nonint(expr, x_var)
        if restrict_positive_x:
            x_vals = np.linspace(1e-3, 10, 1000)  # Wider positive domain
        else:
            x_vals = np.linspace(-10, 10, 1000)   # Wider full domain
        f = lambdify(sym_var, expr, "numpy")
        y_vals = f(x_vals)
        y_vals = np.array(y_vals, dtype=np.complex128)
        valid_indices = np.isfinite(y_vals) & (np.isreal(y_vals))
        # Filter out extreme y-values for better visualization
        y_abs_max = 1e4  # Threshold for extreme values
        finite_indices = valid_indices & (np.abs(y_vals) < y_abs_max)
        x_filtered = x_vals[finite_indices]
        y_filtered = np.real(y_vals[finite_indices])
        # Further filter out x very close to zero to avoid singularities
        nonzero_indices = np.abs(x_filtered) > 1e-3
        x_filtered = x_filtered[nonzero_indices]
        y_filtered = y_filtered[nonzero_indices]
        plt.figure(figsize=(8, 6), dpi=100)
        plt.plot(x_filtered, y_filtered, 'b-', linewidth=2)
        plt.axhline(y=0, color='k', linestyle='-', alpha=0.3)
        plt.axvline(x=0, color='k', linestyle='-', alpha=0.3)
        plt.grid(True, alpha=0.3)
        plt.xlabel(x_var)
        plt.ylabel(y_var)
        # Set x-limits with padding and clamping
        if len(x_filtered) > 0:
            x_min = np.min(x_filtered)
            x_max = np.max(x_filtered)
            x_left, x_right = smart_axis_limits(x_min, x_max)
            plt.xlim([x_left, x_right])
        # Set y-limits with padding and clamping
        if len(y_filtered) > 0:
            y_min = np.min(y_filtered)
            y_max = np.max(y_filtered)
            y_bottom, y_top = smart_axis_limits(y_min, y_max)
            plt.ylim([y_bottom, y_top])
        plot_path = 'static/debug_images/plot.png'
        plt.savefig(plot_path, bbox_inches='tight', pad_inches=0.3)
        plt.close()
        return plot_path
    except Exception as e:
        print(f"Error in sympy plotting: {e}")
        import traceback
        traceback.print_exc()
        return None

def smart_axis_limits(min_val, max_val, min_limit=-10, max_limit=10, min_width=1):
    # Clamp to reasonable limits
    min_val = max(min_val, min_limit)
    max_val = min(max_val, max_limit)
    # Ensure minimum width
    if max_val - min_val < min_width:
        center = (max_val + min_val) / 2
        min_val = center - min_width / 2
        max_val = center + min_width / 2
    # Add 10% padding
    padding = (max_val - min_val) * 0.1
    return min_val - padding, max_val + padding

@app.route('/receive', methods=['POST'])
def receive_prediction():
    """Endpoint for receiving prediction string from PYNQ"""
    global LATEST_PREDICTION
    try:
        data = request.get_json(force=True) or {}
        print("[SERVER] Prediction arrived:", data)
        
        # Store the prediction text in the global variable
        if 'text' in data:
            LATEST_PREDICTION = data['text'].strip()
        
        # If you want to save data['text'] or update UI - this is the place
        return jsonify({"ok": True})
    except Exception as e:
        print(f"[SERVER] Error in receive_prediction: {e}")
        return jsonify({"ok": False, "error": str(e)}), 400

# Route to handle feedback submissions
@app.route('/feedback', methods=['POST'])
def record_feedback():
    try:
        # Get feedback data from request
        data = request.json
        print(f"[FEEDBACK] Received feedback data: {data}")
        
        recognized = data.get('recognized', '')
        is_correct = data.get('is_correct', False)
        correction = data.get('correction', None)
        timestamp = data.get('timestamp', datetime.now().isoformat())
        
        print(f"[FEEDBACK] Processing: recognized='{recognized}', is_correct={is_correct}, correction='{correction}'")
        
        # Read existing feedback data
        try:
            with open(FEEDBACK_FILE, 'r') as f:
                feedback_data = json.load(f)
                print(f"[FEEDBACK] Successfully loaded existing data with {len(feedback_data.get('feedback_entries', []))} entries")
        except (FileNotFoundError, json.JSONDecodeError) as file_error:
            # If file doesn't exist or is invalid, create a new data structure
            print(f"[FEEDBACK] Error loading feedback file: {file_error}. Creating new data structure.")
            feedback_data = {
                'feedback_entries': [],
                'stats': {
                    'total': 0,
                    'correct': 0,
                    'incorrect': 0,
                    'accuracy': 0
                }
            }
        
        # Add new feedback entry
        feedback_data['feedback_entries'].append({
            'recognized': recognized,
            'is_correct': is_correct,
            'correction': correction,
            'timestamp': timestamp
        })
        
        # Update statistics
        stats = feedback_data['stats']
        stats['total'] += 1
        if is_correct:
            stats['correct'] += 1
        else:
            stats['incorrect'] += 1
        
        # Calculate accuracy
        stats['accuracy'] = round((stats['correct'] / stats['total']) * 100, 2) if stats['total'] > 0 else 0
        
        # Save updated feedback data
        with open(FEEDBACK_FILE, 'w') as f:
            json.dump(feedback_data, f, indent=2)
            print(f"[FEEDBACK] Successfully saved feedback data with {len(feedback_data['feedback_entries'])} entries")
        
        return jsonify({
            'success': True, 
            'message': 'Feedback recorded',
            'current_accuracy': stats['accuracy']
        })
    except Exception as e:
        print(f"[FEEDBACK] Error recording feedback: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'success': False, 'error': str(e)}), 500


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False) 