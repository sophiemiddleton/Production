#!/usr/bin/env python3

import sys
import subprocess

def transform_filename(filename: str) -> str:
    """
    Split the filename on dots, replace the first segment with 'cnf'
    and the last segment with 'tar', then join back together with dots.
    """
    parts = filename.split('.')
    parts[0] = 'cnf'    # Replace first field with 'cnf'
    parts[-1] = 'tar'   # Replace last field (extension) with 'tar'
    parts[-2] = '0'   # Replace last field (extension) with 'tar'
    return '.'.join(parts)

def main():
    # 1) Check command-line args
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <input_file>")
        sys.exit(1)
    
    input_file = sys.argv[1]

    # Transform the input file name to par file
    transformed_file = transform_filename(input_file)
    print(f"Par file: {transformed_file}")

    # Locate the par file via samweb
    try:
        location_bytes = subprocess.check_output(["samweb", "locate-file", transformed_file])
    except subprocess.CalledProcessError as e:
        print(f"Error: samweb locate-file failed for {transformed_file}")
        print(e)
        sys.exit(1)

    location_str = location_bytes.decode().strip()
    
    # Strip off 'dcache:' prefix
    if location_str.startswith("dcache:"):
        location_str = location_str[len("dcache:"):]

    # Form the full path to par file
    full_path = f"{location_str}/{transformed_file}"
    print(f"Par file located at: {full_path}")
    print("++++++++++++++++++++++++++++++++++++++++")
    
    # Call mu2ejobfcl
    try:
        subprocess.run([
            "mu2ejobfcl",
            "--jobdef", full_path,
            "--target", input_file,
            "--default-proto", "root",
            "--default-loc", "tape"
        ], check=True)
    except subprocess.CalledProcessError as e:
        print("Error: mu2ejobfcl command failed.")
        print(e)
        sys.exit(1)

if __name__ == "__main__":
    main()
