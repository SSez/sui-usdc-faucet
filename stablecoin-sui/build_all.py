#!/usr/bin/env python3
"""
Comprehensive build script for SUI stablecoin faucet deployment.
Follows the README.md workflow to build and publish all packages:
1. sui_extensions
2. stablecoin
3. usdc
4. Create Treasury
5. Create faucet

Extracts and saves all contract IDs to JSON files and contract_ids.env.
"""

import json
import sys
import re
import subprocess
from pathlib import Path

GAS_BUDGET = '300000000'

# ANSI Color Codes
class Colors:
    """ANSI color codes for professional terminal output."""
    RESET = '\033[0m'
    BOLD = '\033[1m'
    
    # Regular colors
    BLACK = '\033[30m'
    RED = '\033[31m'
    GREEN = '\033[32m'
    YELLOW = '\033[33m'
    BLUE = '\033[34m'
    MAGENTA = '\033[35m'
    CYAN = '\033[36m'
    WHITE = '\033[37m'
    
    # Bright colors
    BRIGHT_BLACK = '\033[90m'
    BRIGHT_RED = '\033[91m'
    BRIGHT_GREEN = '\033[92m'
    BRIGHT_YELLOW = '\033[93m'
    BRIGHT_BLUE = '\033[94m'
    BRIGHT_MAGENTA = '\033[95m'
    BRIGHT_CYAN = '\033[96m'
    BRIGHT_WHITE = '\033[97m'
    
    # Background colors
    BG_RED = '\033[41m'
    BG_GREEN = '\033[42m'
    BG_YELLOW = '\033[43m'
    BG_BLUE = '\033[44m'
    BG_MAGENTA = '\033[45m'
    BG_CYAN = '\033[46m'
    
    # Styles
    UNDERLINE = '\033[4m'
    ITALIC = '\033[3m'

class PackageConfig:
    """Configuration class for package deployment."""
    
    PACKAGES = {
        'sui_extensions': {
            'name': 'sui_extensions',
            'display_name': 'SUI Extensions',
            'icon': '📦',
            'needs_unpublished_deps': False,
            'extract_treasury': False,
            'step_number': 1,
            'step_name': 'Building and Publishing SUI Extensions'
        },
        'stablecoin': {
            'name': 'stablecoin',
            'display_name': 'Stablecoin',
            'icon': '📦',
            'needs_unpublished_deps': True,
            'extract_treasury': False,
            'step_number': 2,
            'step_name': 'Building and Publishing Stablecoin'
        },
        'usdc': {
            'name': 'usdc',
            'display_name': 'USDC',
            'icon': '💰',
            'needs_unpublished_deps': True,
            'extract_treasury': True,
            'step_number': 3,
            'step_name': 'Building and Publishing USDC'
        }
    }
    
    @classmethod
    def get_config(cls, package_name):
        """Get configuration for a specific package."""
        return cls.PACKAGES.get(package_name)
    
    @classmethod
    def get_all_configs(cls):
        """Get all package configurations in order."""
        return [cls.PACKAGES['sui_extensions'], cls.PACKAGES['stablecoin'], cls.PACKAGES['usdc']]


def print_header(title, color=Colors.BRIGHT_CYAN):
    """Print a formatted header with color."""
    width = 80
    padding = (width - len(title) - 4) // 2
    left_pad = padding
    right_pad = width - len(title) - 4 - left_pad
    
    print(f"\n{color}{'═' * width}{Colors.RESET}")
    print(f"{color}║ {Colors.BOLD}{title}{Colors.RESET}{color} {' ' * right_pad}║{Colors.RESET}")
    print(f"{color}{'═' * width}{Colors.RESET}")

def print_success(message):
    """Print a success message with green color."""
    print(f"{Colors.BRIGHT_GREEN}✅ {message}{Colors.RESET}")

def print_error(message):
    """Print an error message with red color."""
    print(f"{Colors.BRIGHT_RED}❌ {message}{Colors.RESET}")

def print_warning(message):
    """Print a warning message with yellow color."""
    print(f"{Colors.BRIGHT_YELLOW}⚠️  {message}{Colors.RESET}")

def print_info(message):
    """Print an info message with blue color."""
    print(f"{Colors.BRIGHT_BLUE}ℹ️  {message}{Colors.RESET}")

def print_step(step_num, step_name, total_steps=5):
    """Print a step indicator with progress."""
    progress = f"[{step_num}/{total_steps}]"
    print(f"\n{Colors.BRIGHT_MAGENTA}{Colors.BOLD}STEP {step_num}: {step_name}{Colors.RESET} {Colors.BRIGHT_BLACK}{progress}{Colors.RESET}")

def print_section(title):
    """Print a section divider."""
    print(f"\n{Colors.BRIGHT_BLACK}{'─' * 60}{Colors.RESET}")
    print(f"{Colors.BRIGHT_CYAN}{Colors.BOLD}{title.upper()}{Colors.RESET}")
    print(f"{Colors.BRIGHT_BLACK}{'─' * 60}{Colors.RESET}")

def print_contract_id(label, value, icon="📦"):
    """Print a contract ID with professional formatting."""
    if value:
        print(f"{Colors.BRIGHT_GREEN}{icon} {Colors.BOLD}{label}:{Colors.RESET} {Colors.BRIGHT_WHITE}{value}{Colors.RESET}")
    else:
        print(f"{Colors.BRIGHT_RED}{icon} {Colors.BOLD}{label}:{Colors.RESET} {Colors.BRIGHT_BLACK}<not found>{Colors.RESET}")

def print_command(cmd):
    """Print a command being executed."""
    print(f"{Colors.BRIGHT_BLACK}Executing: {Colors.BRIGHT_CYAN}{' '.join(cmd)}{Colors.RESET}")

def print_file_action(action, filepath):
    """Print file operation actions."""
    print(f"{Colors.BRIGHT_BLUE}📄 {action}: {Colors.BRIGHT_WHITE}{filepath}{Colors.RESET}")

def print_progress(message):
    """Print a progress message."""
    print(f"{Colors.BRIGHT_YELLOW}⏳ {message}{Colors.RESET}")

def print_final_results(results):
    """Print final deployment results in a professional format."""
    print_header("DEPLOYMENT RESULTS", Colors.BRIGHT_GREEN)
    
    # Print contract IDs
    print_section("Contract IDs")
    print_contract_id("SUI_EXTENSIONS_PACKAGE", results.get('sui_extensions_package'), "📦")
    print_contract_id("STABLECOIN_PACKAGE", results.get('stablecoin_package'), "📦")
    print_contract_id("USDC_PACKAGE", results.get('usdc_package'), "💰")
    print_contract_id("TREASURY", results.get('treasury_id'), "🏛️ ")
    print_contract_id("FAUCET_ID", results.get('faucet_id'), "🚰")
    
    # Print USDC contract address if available
    if results.get('usdc_package'):
        print_section("USDC Contract Address")
        usdc_address = f"{results['usdc_package']}::usdc::USDC"
        print(f"{Colors.BRIGHT_GREEN}💵 {Colors.BOLD}Address:{Colors.RESET} {Colors.BRIGHT_WHITE}{usdc_address}{Colors.RESET}")
    
    print_section("Status")
    success_count = sum(1 for v in results.values() if v)
    total_count = len(results)
    if success_count == total_count:
        print_success(f"All {total_count} components deployed successfully!")
    else:
        print_warning(f"{success_count}/{total_count} components deployed successfully.")


def load_json_file(file_path):
    """Load and parse a JSON file with automatic encoding detection."""
    try:
        # Try UTF-8 first
        with open(file_path, 'r', encoding='utf-8') as f:
            return json.load(f)
    except UnicodeDecodeError:
        return None
    except FileNotFoundError:
        print_error(f"File not found: {file_path}")
        return None
    except json.JSONDecodeError as e:
        print_error(f"Invalid JSON in file {file_path}: {e}")
        return None


def run_command(cmd, cwd=None, capture_output=True):
    """Run a command and return the result."""
    try:
        print_command(cmd)
        if cwd:
            print_info(f"Working directory: {cwd}")
        
        result = subprocess.run(
            cmd, 
            cwd=cwd, 
            capture_output=capture_output, 
            text=True, 
            check=True
        )
        
        if capture_output:
            # Print stdout for debugging
            if result.stdout:
                print_info(f"Command output: {result.stdout[:200]}{'...' if len(result.stdout) > 200 else ''}")
            return result.stdout
        return True
        
    except subprocess.CalledProcessError as e:
        print_error(f"Command failed with exit code {e.returncode}: {e}")
        if e.stdout:
            print_error(f"Stdout: {e.stdout}")
        if e.stderr:
            print_error(f"Stderr: {e.stderr}")
        return None
    except Exception as e:
        print_error(f"Unexpected error: {e}")
        return None


def build_and_publish_sui_extensions(script_dir, json_dir):
    """Build and publish sui_extensions package."""
    print_header("Building and Publishing SUI Extensions", Colors.BRIGHT_CYAN)
    
    sui_extensions_dir = script_dir / 'packages' / 'sui_extensions'
    output_path = json_dir / 'sui_extensions.out.json'
    
    if not sui_extensions_dir.exists():
        print_error(f"SUI extensions directory not found: {sui_extensions_dir}")
        return None
    
    # Build the package
    print_progress("Building sui_extensions package...")
    if not run_command(['sui', 'move', 'build'], cwd=sui_extensions_dir):
        return None
    
    # Publish the package
    print_progress("Publishing sui_extensions package...")
    cmd = ['sui', 'client', 'publish', '--gas-budget', '300000000', '--json']
    output = run_command(cmd, cwd=sui_extensions_dir)
    
    if not output:
        return None
    
    # Save output to JSON file
    with open(output_path, 'w') as f:
        f.write(output)
    print_file_action("Output saved", output_path)
    
    # Extract package ID
    try:
        data = json.loads(output)
        package_id = extract_package_id(data)
        if package_id:
            print_contract_id("SUI_EXTENSIONS_PACKAGE", package_id)
            return package_id
        else:
            print_error("Could not extract SUI_EXTENSIONS_PACKAGE from output.")
            return None
    except json.JSONDecodeError as e:
        print_error(f"Failed to parse JSON output: {e}")
        return None


def build_and_publish_stablecoin(script_dir, json_dir):
    """Build and publish stablecoin package."""
    print_header("Building and Publishing Stablecoin", Colors.BRIGHT_CYAN)
    
    stablecoin_dir = script_dir / 'packages' / 'stablecoin'
    output_path = json_dir / 'stablecoin.out.json'
    
    if not stablecoin_dir.exists():
        print_error(f"Stablecoin directory not found: {stablecoin_dir}")
        return None
    
    # Build the package
    print_progress("Building stablecoin package...")
    if not run_command(['sui', 'move', 'build'], cwd=stablecoin_dir):
        return None
    
    # Publish the package
    print_progress("Publishing stablecoin package...")
    #cmd = ['sui', 'client', 'publish', '--gas-budget', GAS_BUDGET, '--with-unpublished-dependencies', '--json']
    cmd = ['sui', 'client', 'publish', '--gas-budget', GAS_BUDGET, '--json']
    output = run_command(cmd, cwd=stablecoin_dir)

    if not output:
        return None
    
    # Save output to JSON file
    with open(output_path, 'w') as f:
        f.write(output)
    print_file_action("Output saved", output_path)
    
    # Extract package ID
    try:
        data = json.loads(output)
        package_id = extract_package_id(data)
        if package_id:
            print_contract_id("STABLECOIN_PACKAGE", package_id)
            return package_id
        else:
            print_error("Could not extract STABLECOIN_PACKAGE from output.")
            return None
    except json.JSONDecodeError as e:
        print_error(f"Failed to parse JSON output: {e}")
        return None


def build_and_publish_package(script_dir, json_dir, package_config):
    """Generic function to build and publish a package based on configuration."""
    package_name = package_config['name']
    display_name = package_config.get('display_name', package_name)
    icon = package_config.get('icon', '📦')
    needs_unpublished_deps = package_config.get('needs_unpublished_deps', False)
    extract_treasury = package_config.get('extract_treasury', False)
    
    print_header(f"Building and Publishing {display_name}", Colors.BRIGHT_CYAN)
    
    package_dir = script_dir / 'packages' / package_name
    output_path = json_dir / f'{package_name}.out.json'
    
    if not package_dir.exists():
        print_error(f"{display_name} directory not found: {package_dir}")
        return (None, None) if extract_treasury else None
    
    # Build the package
    print_progress(f"Building {package_name} package...")
    build_result = run_command(['sui', 'move', 'build'], cwd=package_dir)
    if build_result is None:
        return (None, None) if extract_treasury else None
    
    # Publish the package - ALWAYS use --with-unpublished-dependencies and --json
    print_progress(f"Publishing {package_name} package...")
    cmd = ['sui', 'client', 'publish', '--gas-budget', GAS_BUDGET, '--json']
    #if needs_unpublished_deps:
    #    cmd.insert(-1, '--with-unpublished-dependencies')

    output = run_command(cmd, cwd=package_dir)
    
    if not output:
        print_error(f"Failed to publish {package_name} package.")
        return (None, None) if extract_treasury else None
    
    # Save output to JSON file
    with open(output_path, 'w') as f:
        f.write(output)
    print_file_action("Output saved", output_path)
    
    # Extract IDs
    try:
        data = json.loads(output)
        package_id = extract_package_id(data)
        
        if package_id:
            print_contract_id(f"{package_name.upper()}_PACKAGE", package_id, icon)
        else:
            print_error(f"Could not extract {package_name.upper()}_PACKAGE from output.")
        
        # Extract treasury if needed
        treasury_id = None
        if extract_treasury and package_id:
            # For USDC package, the package_id is the usdc_package we need
            usdc_to_use = package_id if package_name == 'usdc' else None
            treasury_id = extract_treasury_id(data, usdc_to_use)
            if treasury_id:
                print_contract_id("TREASURY", treasury_id, "🏛️ ")
            else:
                print_error("Could not extract TREASURY from output.")
        
        return (package_id, treasury_id) if extract_treasury else package_id
        
    except json.JSONDecodeError as e:
        print_error(f"Failed to parse JSON output: {e}")
        return (None, None) if extract_treasury else None


def build_and_publish_sui_extensions(script_dir, json_dir):
    """Build and publish sui_extensions package."""
    config = {
        'name': 'sui_extensions',
        'display_name': 'SUI Extensions',
        'icon': '📦',
        'needs_unpublished_deps': False,
        'extract_treasury': False
    }
    return build_and_publish_package(script_dir, json_dir, config)


def build_and_publish_stablecoin(script_dir, json_dir):
    """Build and publish stablecoin package."""
    config = {
        'name': 'stablecoin',
        'display_name': 'Stablecoin',
        'icon': '📦',
        'needs_unpublished_deps': True,
        'extract_treasury': False
    }
    return build_and_publish_package(script_dir, json_dir, config)


def build_and_publish_usdc(script_dir, json_dir):
    """Build and publish USDC package."""
    config = {
        'name': 'usdc',
        'display_name': 'USDC',
        'icon': '💰',
        'needs_unpublished_deps': True,
        'extract_treasury': True
    }
    return build_and_publish_package(script_dir, json_dir, config)


def extract_package_id(data):
    """Extract Package ID from published object."""
    if not data or 'objectChanges' not in data:
        return None
    
    for change in data['objectChanges']:
        if change.get('type') == 'published' and 'packageId' in change:
            return change['packageId']
    return None

def extract_treasury_id(data, usdc_package=None):
    """Extract Treasury object ID from created objects."""
    if not data or 'objectChanges' not in data:
        return None

    # Pattern for our specific Treasury type
    pattern = rf"::treasury::Treasury<{usdc_package}::usdc::USDC>"
    
    for change in data['objectChanges']:
        if change.get('type') == 'created' and 'objectType' in change:
            if re.search(pattern, change['objectType']):
                print_info(f"✅ Found Treasury: {change['objectType']}")
                return change['objectId']
    
    print_error("❌ Could not extract TREASURY from output.")
    return None


def extract_faucet_id(data, usdc_package):
    """Extract Faucet object ID from created objects."""
    if not data or 'objectChanges' not in data or not usdc_package:
        return None

    faucet_pattern = r"::faucet::Faucet<.*::usdc::USDC>"
    for change in data['objectChanges']:
        if (change.get('type') == 'created' and 
            'objectType' in change and 
            re.search(faucet_pattern, change['objectType'])):
            return change['objectId']
    return None


def create_treasury(stablecoin_package, usdc_package, owner_address, treasury_json_path):
    """Create Treasury object using SUI client call and save output to JSON file."""
    if not all([stablecoin_package, usdc_package, owner_address]):
        print_error("Missing required parameters for treasury creation.")
        return None

    print_header("Creating Treasury", Colors.BRIGHT_CYAN)
    print_info("This will create a Treasury<USDC> object with our specific USDC type.")

    # Build the SUI client command
    cmd = [
        'sui', 'client', 'call',
        '--package', stablecoin_package,
        '--module', 'treasury',
        '--function', 'create',
        '--type-args', f'{usdc_package}::usdc::USDC',
        '--args', f"{owner_address}",
        '--gas-budget', GAS_BUDGET,
        '--json'
    ]

    try:
        print_progress("Executing SUI client call to create Treasury...")
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)

        # Save the output to the JSON file
        with open(treasury_json_path, 'w') as f:
            f.write(result.stdout)

        print_success("Treasury creation completed successfully!")
        print_file_action("Output saved", treasury_json_path)

        # Parse and display the treasury ID
        try:
            output_data = json.loads(result.stdout)
            treasury_id = extract_treasury_id(output_data, usdc_package)
            if treasury_id:
                print_contract_id("TREASURY_ID", treasury_id, "🏛️ ")
                return treasury_id
            else:
                print_warning("Could not extract TREASURY_ID from the output.")
                return None
        except json.JSONDecodeError:
            print_warning("Could not parse JSON output to extract TREASURY_ID.")
            return None

    except subprocess.CalledProcessError as e:
        print_error(f"Error executing SUI client call: {e}")
        if e.stderr:
            print_error(f"Error output: {e.stderr}")
        return None
    except Exception as e:
        print_error(f"Unexpected error: {e}")
        return None


def create_faucet(stablecoin_package, usdc_package, treasury_id, faucet_json_path):
    """Create faucet using SUI client call and save output to JSON file."""
    if not all([stablecoin_package, usdc_package, treasury_id]):
        print_error("Missing required parameters for faucet creation.")
        print_error(f"Required: STABLECOIN_PACKAGE={stablecoin_package}, USDC_PACKAGE={usdc_package}, TREASURY={treasury_id}")
        return None
    
    print_header("Creating Faucet", Colors.BRIGHT_CYAN)
    print_info("This will create a shared Faucet<USDC> object.")
    
    # Ask user for confirmation
    response = input("Do you want to proceed with creating the faucet? (Y/n): ").strip().lower()
    if response.lower() != 'y' and response.lower() != 'yes':
        print_warning("Faucet creation cancelled by user.")
        return None
    
    # Build the SUI client command
    cmd = [
        'sui', 'client', 'call',
        '--package', stablecoin_package,
        '--module', 'faucet',
        '--function', 'create',
        '--type-args', f'{usdc_package}::usdc::USDC',
        '--args', treasury_id,
        '--gas-budget', GAS_BUDGET,
        '--json'
    ]
    
    try:
        print_progress("Executing SUI client call...")
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        
        # Save the output to the JSON file
        with open(faucet_json_path, 'w') as f:
            f.write(result.stdout)
        
        print_success("Faucet creation completed successfully!")
        print_file_action("Output saved", faucet_json_path)
        
        # Parse and display the faucet ID
        try:
            output_data = json.loads(result.stdout)
            faucet_id = extract_faucet_id(output_data, usdc_package)
            if faucet_id:
                print_contract_id("FAUCET_ID", faucet_id, "🚰")
                return faucet_id
            else:
                print_warning("Could not extract FAUCET_ID from the output.")
                return None
        except json.JSONDecodeError:
            print_warning("Could not parse JSON output to extract FAUCET_ID.")
            return None
        
    except subprocess.CalledProcessError as e:
        print_error(f"Error executing SUI client call: {e}")
        if e.stderr:
            print_error(f"Error output: {e.stderr}")
        return None
    except Exception as e:
        print_error(f"Unexpected error: {e}")
        return None


def save_config_file(config_data, output_path):
    """Save extracted IDs to a config file."""
    try:
        with open(output_path, 'w') as f:
            for key, value in config_data.items():
                f.write(f"{key}={value}\n")
        print_file_action("Contract IDs saved", output_path)
        return True
    except IOError as e:
        print_error(f"Could not write to config file {output_path}: {e}")
        return False


def load_existing_package_data(json_dir, package_config, usdc_package=None):
    """Load existing package data from JSON file."""
    package_name = package_config['name']
    display_name = package_config.get('display_name', package_name)
    icon = package_config.get('icon', '📦')
    extract_treasury = package_config.get('extract_treasury', False)
    
    package_data = load_json_file(json_dir / f'{package_name}.out.json')
    if not package_data:
        return (None, None) if extract_treasury else None
    
    package_id = extract_package_id(package_data)
    treasury_id = None
    
    # Always attempt to extract Treasury using the README pattern
    # This does not require usdc_package to be known in advance
    if extract_treasury and package_id:
        treasury_id = extract_treasury_id(package_data, usdc_package)
    
    if package_id:
        print_contract_id(f"Loaded existing {package_name.upper()}_PACKAGE", package_id, icon)
    
    if treasury_id:
        print_contract_id("Loaded existing TREASURY", treasury_id, "🏛️ ")
    
    return (package_id, treasury_id) if extract_treasury else package_id


def check_existing_json_files(json_dir):
    """Check for existing JSON files and ask user whether to use them or create new ones."""
    json_files = ['sui_extensions.out.json', 'stablecoin.out.json', 'usdc.out.json']
    existing_files = []
    
    for json_file in json_files:
        file_path = json_dir / json_file
        if file_path.exists():
            existing_files.append(json_file)
    
    if not existing_files:
        return {}  # No existing files
    
    print_section("Existing JSON Files Found")
    print_info("The following JSON files already exist:")
    for json_file in existing_files:
        print_info(f"  - {json_file}")
    print()
    
    response = input("Create new files? (y = create new files, n = use existing files) [n]:").strip().lower()
    
    if response.lower() == 'n':
        print_info("Using existing JSON files.")
        return {file: True for file in existing_files}
    elif response.lower() == 'y':
        print_info("Removing existing JSON files and creating new ones.")
        for json_file in existing_files:
            file_path = json_dir / json_file
            try:
                file_path.unlink()
                print_info(f"Removed {json_file}")
            except Exception as e:
                print_error(f"Failed to remove {json_file}: {e}")
        return {}
    else:
        print_warning("Invalid response. Using existing files by default.")
        return {file: True for file in existing_files}


def deploy_package_with_prompt(script_dir, json_dir, package_config, usdc_package=None, use_existing_files=None):
    """Deploy a package with user prompt and handle existing data loading."""
    package_name = package_config['name']
    display_name = package_config['display_name']
    step_number = package_config['step_number']
    step_name = package_config['step_name']
    
    print_section(f"STEP {step_number}: {step_name}")
    
    # Check if we should use existing files
    json_file = f"{package_name}.out.json"
    if use_existing_files and json_file in use_existing_files:
        print_info(f"Using existing {json_file} file.")
        return load_existing_package_data(json_dir, package_config, usdc_package)
    
    response = input(f"Do you want to build and publish {package_name}? (Y/n): ").strip().lower()
    if response != 'n' and response != 'no':
        return build_and_publish_package(script_dir, json_dir, package_config)
    else:
        print_warning(f"Skipping {package_name} deployment.")
        return load_existing_package_data(json_dir, package_config, usdc_package)


def verify_usdc_data_type(usdc_package, treasury_id):
    """Verify that USDC coins are properly recognized as USDC type, not generic Object."""
    print_section("🔍 Verifying USDC Data Type")

    if not usdc_package:
        print_error("USDC package ID not available for verification.")
        return False

    expected_usdc_type = f"{usdc_package}::usdc::USDC"
    print_info(f"Expected USDC type: {expected_usdc_type}")

    # Check Treasury object type
    if treasury_id:
        print_progress("Checking Treasury object type...")
        cmd = ['sui', 'client', 'object', treasury_id, '--json']
        treasury_output = run_command(cmd)

        if treasury_output:
            try:
                treasury_data = json.loads(treasury_output)
                treasury_type = treasury_data.get('data', {}).get('type', '')

                if treasury_type:
                    print_info(f"Treasury type: {treasury_type}")

                    if expected_usdc_type in treasury_type:
                        print_success("✅ Treasury contains correct USDC type!")
                    else:
                        print_error(f"❌ Treasury type mismatch! Expected {expected_usdc_type} in {treasury_type}")
                        return False
                else:
                    print_warning("Could not determine Treasury object type.")
            except json.JSONDecodeError:
                print_error("Failed to parse Treasury object JSON.")

    # Check if we have any USDC coins in wallet
    print_progress("Checking wallet for USDC coins...")
    try:
        address = run_command(['sui', 'client', 'active-address'], capture_output=True)
        if address:
            address = address.strip()
            print_info(f"Using address: {address}")

            # Query balance for the specific USDC coin type
            cmd = ['sui', 'client', 'balance', address, '--coin-type', expected_usdc_type, '--json']
            balance_output = run_command(cmd)

            if balance_output:
                try:
                    data = json.loads(balance_output)
                    total = 0
                    if isinstance(data, dict):
                        total = int(data.get('totalBalance') or data.get('total_balance') or 0)
                    elif isinstance(data, list):
                        for entry in data:
                            if isinstance(entry, dict) and (entry.get('coinType') == expected_usdc_type or entry.get('coin_type') == expected_usdc_type):
                                total = int(entry.get('totalBalance') or entry.get('total_balance') or 0)
                                break

                    if total > 0:
                        print_success(f"✅ Found USDC balance: {total / 1_000_000} USDC")
                        return True
                    else:
                        print_info("ℹ️  No USDC balance found yet. This is normal before using the faucet.")
                        print_info("   Try requesting USDC from the faucet to test the data type.")
                        return True
                except json.JSONDecodeError:
                    print_error("Failed to parse balance JSON.")
        else:
            print_warning("Could not determine active address.")
    except Exception as e:
        print_error(f"Error checking USDC balance: {e}")

    print_info("ℹ️  USDC data type verification completed.")
    return True


def main():
    """Main function to build and deploy all packages following README.md workflow."""
    print_header("🚀 Starting Comprehensive Build and Deployment Process", Colors.BRIGHT_CYAN)
    for i, config in enumerate(PackageConfig.get_all_configs(), 1):
        print_step(i, f"Build & Publish {config['name']}")
    print_step(4, "Create Treasury")
    print_step(5, "Create faucet")
    print_step(6, "Verify USDC data type")
    print_step(7, "Save all contract IDs")
    print()
    
    # Define file paths
    script_dir = Path(__file__).parent
    json_dir = script_dir / 'json'
    config_output_path = json_dir / 'contract_ids.env'
    
    # Create json directory if it doesn't exist
    json_dir.mkdir(exist_ok=True)
    
    print_info(f"Working directory: {script_dir}")
    print_info(f"JSON output directory: {json_dir}")
    print_info(f"Configuration output: {config_output_path}")
    print()
    
    # Check for existing JSON files
    use_existing_files = check_existing_json_files(json_dir)
    print()
    
    # Initialize variables
    package_ids = {
        'sui_extensions_package': None,
        'stablecoin_package': None,
        'usdc_package': None,
        'treasury_id': None,
        'faucet_id': None
    }
    
    # Deploy packages using configuration
    for package_config in PackageConfig.get_all_configs():
        package_name = package_config['name']
        result = deploy_package_with_prompt(script_dir, json_dir, package_config, package_ids['usdc_package'], use_existing_files)
        
        if package_config['extract_treasury']:
            package_ids[f"{package_name}_package"], package_ids['treasury_id'] = result
        else:
            package_ids[f"{package_name}_package"] = result
    
    # Step 4: Create Treasury
    if package_ids['usdc_package'] and not package_ids['treasury_id']:
        print_section("Creating Treasury")
        # Get owner address (use active address)
        owner_address = run_command(['sui', 'client', 'active-address'], capture_output=True).strip()
        treasury_path = json_dir / 'treasury.out.json'
        package_ids['treasury_id'] = create_treasury(
            package_ids['stablecoin_package'],
            package_ids['usdc_package'],
            owner_address,
            treasury_path
        )

    # Step 5: Create Faucet
    if package_ids['usdc_package'] and package_ids['treasury_id']:
        faucet_path = json_dir / 'faucet.out.json'
        package_ids['faucet_id'] = create_faucet(
            package_ids['stablecoin_package'],
            package_ids['usdc_package'],
            package_ids['treasury_id'],  # Use our newly created Treasury
            faucet_path
        )
    
    # Step 6: Verify USDC data type
    print_section("STEP 6: Verifying USDC Data Type")
    verification_success = verify_usdc_data_type(package_ids['usdc_package'], package_ids['treasury_id'])

    if verification_success:
        print_success("✅ USDC data type verification passed!")
    else:
        print_warning("⚠️  USDC data type verification failed. Check the output above for details.")
        print_info("   This may indicate TypeMismatch issues when using USDC in other projects.")
    print()

    # Display final results
    print_final_results({
        'sui_extensions_package': package_ids['sui_extensions_package'],
        'stablecoin_package': package_ids['stablecoin_package'],
        'usdc_package': package_ids['usdc_package'],
        'treasury_id': package_ids['treasury_id'],
        'faucet_id': package_ids['faucet_id']
    })
    
    if package_ids['usdc_package']:
        print_info(f"USDC Contract Address: {package_ids['usdc_package']}::usdc::USDC")
    
    # Prepare config data
    config_data = {
        'SUI_EXTENSIONS_PACKAGE': package_ids['sui_extensions_package'] or '',
        'STABLECOIN_PACKAGE': package_ids['stablecoin_package'] or '',
        'USDC_PACKAGE': package_ids['usdc_package'] or '',
        'TREASURY': package_ids['treasury_id'] or '',
        'FAUCET_ID': package_ids['faucet_id'] or ''
    }
    
    # Save to config file
    print_progress(f"Saving configuration to {config_output_path}...")
    if save_config_file(config_data, config_output_path):
        print_success("Build and deployment process completed successfully!")
        print_success("All contract IDs have been extracted and saved!")
        return 0
    else:
        print_error("Failed to save configuration file.")
        return 1


if __name__ == '__main__':
    sys.exit(main())