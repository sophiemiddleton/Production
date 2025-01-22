import configparser
import sys
import subprocess
import os

def format_ini():
    if len(sys.argv) != 2:
        print("Usage: python script.py <input_file>")
        sys.exit(1)
    
    input_file = sys.argv[1]
    
    # Create new output filename by adding '_uploaded'
    file_name, file_ext = os.path.splitext(input_file)
    output_file = f"{file_name}_uploaded{file_ext}"
    
    config = configparser.ConfigParser(interpolation=None)
    config.read(input_file)

    # Remove any indentaions from param_overrides and campaign_keywords sections
    for section in config.sections():
        if 'param_overrides' in config[section]:
            value = config[section]['param_overrides']
            formatted = value.replace('\n', '').replace('    ', '')
            config[section]['param_overrides'] = formatted
            
        if 'campaign_keywords' in config[section]:
            value = config[section]['campaign_keywords']
            formatted = value.replace('\n', '').replace('    ', '')
            config[section]['campaign_keywords'] = formatted
    
    with open(output_file, 'w') as f:
        config.write(f)
    print(f"Successfully formatted {input_file} and saved to {output_file}")
    
    # Upload new ini file using upload_wf
    # Need to: source /cvmfs/fermilab.opensciencegrid.org/packages/common/setup-env.sh; spack load poms-client/hplsffi
    cmd = ["upload_wf", "--poms_role=production", output_file]
    result = subprocess.run(cmd, capture_output=True, text=True)
    print("\nUpload command output:")
    print(result.stdout)
    if result.stderr:
        print("Errors:")
        print(result.stderr)

if __name__ == "__main__":
    format_ini()
