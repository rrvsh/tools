#!/usr/bin/env python3

# original at https://gist.github.com/yinonburgansky/7be4d0489a0df8c06a923240b8eb0191
# modified for ease of use in Hyprland
# calculation are based on http://www.esreality.com/index.php?a=post&id=1945096
# assuming windows 10 uses the same calculation as windows 7.
# guesses have been made calculation is not accurate
# touchpad users make sure your touchpad is calibrated with `sudo libinput measure touchpad-size`

# import matplotlib.pyplot as plt
import struct
import os
import sys
import subprocess
import json


def get_env_or_default(var_name, default_value, type_func=float):
    """Get value from environment variable or use default."""
    val = os.environ.get(var_name)
    if val is not None:
        try:
            return type_func(val)
        except ValueError:
            pass
    return default_value


def calculate_screen_dpi():
    """Calculate screen DPI from Hyprland monitor config.
    
    For 34" 4K (3840x2160):
    - Diagonal pixels = sqrt(3840^2 + 2160^2) = ~4406 pixels
    - DPI = 4406 / 34 = ~130 DPI
    """
    # Try to get from environment first
    dpi = get_env_or_default('SCREEN_DPI', None)
    if dpi is not None:
        return dpi
    
    # Try to calculate from hyprctl monitors
    try:
        result = subprocess.run(
            ['hyprctl', 'monitors', '-j'],
            capture_output=True, text=True, timeout=5
        )
        if result.returncode == 0:
            monitors = json.loads(result.stdout)
            if monitors:
                # Use the first monitor's resolution
                mon = monitors[0]
                width = mon.get('width', 3840)
                height = mon.get('height', 2160)
                
                # Calculate diagonal in pixels
                diagonal_pixels = (width**2 + height**2)**0.5
                
                # 34 inch diagonal (can be overridden via SCREEN_DIAGONAL_INCHES)
                diagonal_inches = get_env_or_default('SCREEN_DIAGONAL_INCHES', 34.0)
                
                dpi = diagonal_pixels / diagonal_inches
                print(f"Calculated screen DPI: {dpi:.1f} (from {width}x{height} @ {diagonal_inches}\")", file=sys.stderr)
                return dpi
    except Exception as e:
        print(f"Could not calculate screen DPI: {e}", file=sys.stderr)
    
    # Default for 34" 4K
    default_dpi = 4406 / 34  # ~129.6
    print(f"Using default screen DPI: {default_dpi:.1f} (34\" 4K)", file=sys.stderr)
    return default_dpi


def get_screen_scaling_factor():
    """Get screen scaling factor from Hyprland or environment."""
    # Try environment first
    scale = get_env_or_default('SCREEN_SCALING_FACTOR', None)
    if scale is not None:
        return scale
    
    # Try to get from hyprctl monitors
    try:
        result = subprocess.run(
            ['hyprctl', 'monitors', '-j'],
            capture_output=True, text=True, timeout=5
        )
        if result.returncode == 0:
            monitors = json.loads(result.stdout)
            if monitors:
                scale = monitors[0].get('scale', 2.0)
                print(f"Detected screen scaling factor: {scale}", file=sys.stderr)
                return scale
    except Exception as e:
        print(f"Could not detect scaling factor: {e}", file=sys.stderr)
    
    # Default based on user's config (scale 2 for 4K)
    print("Using default scaling factor: 2.0", file=sys.stderr)
    return 2.0


def try_get_mouse_dpi(device_name):
    """Try to query mouse DPI - most mice don't expose this via standard interfaces.
    
    Returns None if DPI cannot be determined.
    """
    # Most gaming mice don't expose DPI via standard Linux interfaces
    # You'd need vendor-specific tools like:
    # - piper/libratbag for supported mice (Logitech, SteelSeries, etc.)
    # - OpenRazer for Razer mice
    # - rivalcfg for SteelSeries
    
    # Try libratbag/piper if available
    try:
        result = subprocess.run(
            ['ratbagctl', 'list'],
            capture_output=True, text=True, timeout=5
        )
        if result.returncode == 0 and device_name.lower() in result.stdout.lower():
            # Try to get DPI for this device
            # This is a simplified check - real implementation would need parsing
            pass
    except FileNotFoundError:
        pass
    
    return None


def find_arg(arg):
    for i in sys.argv:
        if i == arg:
            return True
    return False


if find_arg("help") or find_arg("-h") or find_arg("--help") or find_arg("h"):
    print(f'Usage: {sys.argv[0]} [[accel_profile] [scroll_points] device=<device>]')
    print('')
    print('Environment variables:')
    print('  DEVICE_DPI              - Mouse DPI (default: 1000, most mice cannot be auto-detected)')
    print('  SCREEN_DPI              - Screen DPI (auto-calculated from monitor resolution)')
    print('  SCREEN_DIAGONAL_INCHES  - Screen diagonal in inches (default: 34)')
    print('  SCREEN_SCALING_FACTOR   - Hyprland scaling factor (auto-detected from hyprctl)')
    print('  SENSITIVITY_FACTOR      - Windows sensitivity notch 1-11 (default: 6 = 1.0)')
    print('  SAMPLE_POINT_COUNT      - Accuracy of curve (default: 20)')
    print('')
    print('To get the device name, run: hyprctl devices')
    exit(0)


# ===== PARAMETERS =====
# Auto-detect or use environment variables
device_dpi = get_env_or_default('DEVICE_DPI', 1000)  # Most mice can't auto-report DPI
screen_dpi = calculate_screen_dpi()
screen_scaling_factor = get_screen_scaling_factor()
sample_point_count = int(get_env_or_default('SAMPLE_POINT_COUNT', 20))
sensitivity_factor = get_env_or_default('SENSITIVITY_FACTOR', 6)

# sensitivity factor translation table: (windows slider notches)
# 1 = 0.1
# 2 = 0.2
# 3 = 0.4
# 4 = 0.6
# 5 = 0.8
# 6 = 1.0 default
# 7 = 1.2
# 8 = 1.4
# 9 = 1.6
# 10 = 1.8
# 11 = 2.0
# ===== END PARAMETERS =====

print(f"Using device DPI: {device_dpi}", file=sys.stderr)
print(f"Using sensitivity factor: {sensitivity_factor} (Windows notch)", file=sys.stderr)

# TODO: find accurate formulas for scale x and scale y
# mouse speed: inch/s to device-units/millisecond
scale_x = device_dpi / 1e3
# pointer speed: inch/s to screen pixels/millisecond
scale_y = screen_dpi / 1e3 / screen_scaling_factor * sensitivity_factor
# print(f'scale_x={scale_x}, scale_y={scale_y}')


def float16x16(num):
    return struct.unpack('<i', num[:-4])[0] / int(0xffff)


# windows 10 registry values:
# HKEY_CURRENT_USER\Control Panel\Mouse\SmoothMouseXCurve
X = [
    b'\x00\x00\x00\x00\x00\x00\x00\x00',
    b'\x15\x6e\x00\x00\x00\x00\x00\x00',
    b'\x00\x40\x01\x00\x00\x00\x00\x00',
    b'\x29\xdc\x03\x00\x00\x00\x00\x00',
    b'\x00\x00\x28\x00\x00\x00\x00\x00',
]
# HKEY_CURRENT_USER\Control Panel\Mouse\SmoothMouseYCurve
Y = [
    b'\x00\x00\x00\x00\x00\x00\x00\x00',
    b'\xfd\x11\x01\x00\x00\x00\x00\x00',
    b'\x00\x24\x04\x00\x00\x00\x00\x00',
    b'\x00\xfc\x12\x00\x00\x00\x00\x00',
    b'\x00\xc0\xbb\x01\x00\x00\x00\x00',
]

windows_points = [[float16x16(x), float16x16(y)] for x, y in zip(X, Y)]

# scale windows points according to device config
points = [[x * scale_x, y * scale_y] for x, y in windows_points]

# print('Windows original points:')
# for point in windows_points:
#     print(point)

# print('Windows scaled points')
# for point in points:
#     print(point)

# plt.plot(*list(zip(*windows_points)), label=f'windows points')
# plt.plot(*list(zip(*points)), label=f'scaled points')
# plt.xlabel('device-speed')
# plt.ylabel('pointer-speed')
# plt.legend(loc='best')
# plt.show()
# exit()


def get_device():
    for i in sys.argv:
        if str(i).startswith('device='):
            print(str(i)[7::])
            return str(i)[7::]


def find2points(x):
    i = 0
    while i < len(points) - 2 and x >= points[i + 1][0]:
        i += 1
    assert -1e6 + points[i][0] <= x <= points[i + 1][0] + 1e6, f'{points[i][0]} <= {x} <= {points[i+1][0]}'
    return points[i], points[i + 1]


def interpolate(x):
    (x0, y0), (x1, y1) = find2points(x)
    y = ((x - x0) * y1 + (x1 - x) * y0) / (x1 - x0)
    return y


def sample_points(count):
    # use linear extrapolation for last point to get better accuracy for lower points
    last_point = -2
    max_x = points[last_point][0]
    step = max_x / (count + last_point)  # we need another point for 0
    sample_points_x = [si * step for si in range(count)]
    sample_points_y = [interpolate(x) for x in sample_points_x]
    return sample_points_x, sample_points_y


sample_points_x, sample_points_y = sample_points(sample_point_count)
step = sample_points_x[1] - sample_points_x[0]

# plt.plot(sample_points_x, sample_points_y, label=f'windows {sample_point_count} points')
# plt.plot(*sample_points(1024), label=f'windows 1024 points')
# plt.xlabel('device-speed')
# plt.ylabel('pointer-speed')
# plt.legend(loc='best')
# plt.show()
# exit()

sample_points_str = " ".join(["%.3f" % number for number in sample_points_y])
print(f'\tPoints: {sample_points_str}')
print(f'\tStep size: {step:0.10f}')


def hyprctl(device, option, arg):
    os.system(f"hyprctl keyword 'device[{device}]:{option}' '{arg}'")


if find_arg("accel_profile"):
    device = get_device()
    print(f'Setting device:\'{device}\':accel_profile using hyprctl')
    hyprctl(device, 'accel_profile', f'custom {step} {sample_points_str}')
    # os.system(f'hyprctl keyword device:\'{device}\':accel_profile \'custom {step} {sample_points_str}\'')

if find_arg("scroll_points"):
    device = get_device()
    print(f'Setting device:\'{device}\':scroll_points using hyprctl')
    hyprctl(device, 'scroll_points', f'{step} {sample_points_str}')
    # os.system(f'hyprctl keyword device:\'{device}\':scroll_points \'{step} {sample_points_str}\'')
