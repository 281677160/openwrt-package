#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Extract translatable strings from LuCI JavaScript files and shell scripts for i18n template generation.
This script searches for _() function calls in JS files and add_*_entry function calls in shell scripts.
"""

import os
import re
import json
import sys
from pathlib import Path
from typing import Set, Dict, List

def extract_strings_from_file(file_path: str) -> List[Dict[str, any]]:
    """
    Extract all strings from _() calls in a JavaScript file with location info.
    
    Args:
        file_path: Path to the JavaScript file
        
    Returns:
        List of dictionaries containing string, line number, and file path
    """
    strings = []
    
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            lines = f.readlines()
        
        # Pattern to match _('string') or _("string")
        # Handle escaped quotes and multiline strings
        patterns = [
            # Single quoted strings
            r"_\(\s*'([^'\\]*(?:\\.[^'\\]*)*)'\s*\)",
            # Double quoted strings
            r'_\(\s*"([^"\\]*(?:\\.[^"\\]*)*)"\s*\)',
        ]
        
        for line_num, line in enumerate(lines, start=1):
            for pattern in patterns:
                matches = re.finditer(pattern, line)
                for match in matches:
                    string = match.group(1)
                    # Unescape common escape sequences
                    string = string.replace(r"\'", "'")
                    string = string.replace(r'\"', '"')
                    string = string.replace(r"\\", "\\")
                    string = string.replace(r"\n", "\n")
                    string = string.replace(r"\t", "\t")
                    strings.append({
                        'string': string,
                        'line': line_num,
                        'file': file_path
                    })
                
    except Exception as e:
        print(f"Error processing {file_path}: {e}", file=sys.stderr)
    
    return strings

def extract_strings_from_shell_file(file_path: str) -> List[Dict[str, any]]:
    """
    Extract all strings from add_plain_info_entry, add_warning_message_entry, 
    and add_bar_info_entry calls in a shell script file with location info.
    
    Args:
        file_path: Path to the shell script file
        
    Returns:
        List of dictionaries containing string, line number, and file path
    """
    strings = []
    
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            lines = f.readlines()
        
        # Pattern to match the three add_*_entry functions and extract the 3rd parameter
        # These functions have format: add_*_entry "param1" "param2" "param3" ...
        # We want to extract param3 (the translatable string)
        # Pattern to match variables named "class" is also included
        patterns = [
            # Match add_plain_info_entry with 3rd parameter in double quotes
            r'add_plain_info_entry\s+(?:"[^"]*"|\'[^\']*\'|\$\w+)\s+(?:"[^"]*"|\'[^\']*\'|\$\w+)\s+"([^"]+)"',
            # Match add_plain_info_entry with 3rd parameter in single quotes
            r"add_plain_info_entry\s+(?:\"[^\"]*\"|'[^']*'|\$\w+)\s+(?:\"[^\"]*\"|'[^']*'|\$\w+)\s+'([^']+)'",
            # Match add_warning_message_entry with 3rd parameter in double quotes
            r'add_warning_message_entry\s+(?:"[^"]*"|\'[^\']*\'|\$\w+)\s+(?:"[^"]*"|\'[^\']*\'|\$\w+)\s+"([^"]+)"',
            # Match add_warning_message_entry with 3rd parameter in single quotes
            r"add_warning_message_entry\s+(?:\"[^\"]*\"|'[^']*'|\$\w+)\s+(?:\"[^\"]*\"|'[^']*'|\$\w+)\s+'([^']+)'",
            # Match add_bar_info_entry with 3rd parameter in double quotes
            r'add_bar_info_entry\s+(?:"[^"]*"|\'[^\']*\'|\$\w+)\s+(?:"[^"]*"|\'[^\']*\'|\$\w+)\s+"([^"]+)"',
            # Match add_bar_info_entry with 3rd parameter in single quotes
            r"add_bar_info_entry\s+(?:\"[^\"]*\"|'[^']*'|\$\w+)\s+(?:\"[^\"]*\"|'[^']*'|\$\w+)\s+'([^']+)'",
            # Match with all variable named "class" parameters e.g. class="Base Info"
            r"class\s*=\s*\"([^\"]+)\"",
            r"class\s*=\s*'([^']+)'",
        ]
        
        for line_num, line in enumerate(lines, start=1):
            for pattern in patterns:
                matches = re.finditer(pattern, line)
                for match in matches:
                    string = match.group(1)
                    # Unescape common escape sequences
                    string = string.replace(r"\'", "'")
                    string = string.replace(r'\"', '"')
                    string = string.replace(r"\\", "\\")
                    string = string.replace(r"\n", "\n")
                    string = string.replace(r"\t", "\t")
                    strings.append({
                        'string': string,
                        'line': line_num,
                        'file': file_path
                    })
                
    except Exception as e:
        print(f"Error processing {file_path}: {e}", file=sys.stderr)
    
    return strings

def scan_directory(root_dir: str) -> List[Dict[str, any]]:
    """
    Recursively scan directory for JavaScript files and extract strings.
    
    Args:
        root_dir: Root directory to scan
        
    Returns:
        List of dictionaries with string, line, and file information
    """
    results = []
    root_path = Path(root_dir)
    
    if not root_path.exists():
        print(f"Error: Directory {root_dir} does not exist", file=sys.stderr)
        return results
    
    # Find all .js files
    for js_file in root_path.rglob('*.js'):
        strings = extract_strings_from_file(str(js_file))
        if strings:
            # Store relative path for cleaner output
            rel_path = js_file.relative_to(root_path)
            for item in strings:
                item['file'] = str(rel_path)
                results.append(item)
    
    return results

def scan_shell_directory(root_dir: str) -> List[Dict[str, any]]:
    """
    Recursively scan directory for shell script files and extract strings.
    
    Args:
        root_dir: Root directory to scan
        
    Returns:
        List of dictionaries with string, line, and file information
    """
    results = []
    root_path = Path(root_dir)
    
    if not root_path.exists():
        print(f"Error: Directory {root_dir} does not exist", file=sys.stderr)
        return results
    
    # Find all .sh files
    for sh_file in root_path.rglob('*.sh'):
        strings = extract_strings_from_shell_file(str(sh_file))
        if strings:
            # Store relative path for cleaner output
            rel_path = sh_file.relative_to(root_path)
            for item in strings:
                item['file'] = str(rel_path)
                results.append(item)
    
    return results

def generate_po_template(items: List[Dict[str, any]], output_file: str = None):
    """
    Generate a PO (Portable Object) template file.
    
    Args:
        items: List of dictionaries with string, line, and file information
        output_file: Output file path (None for stdout)
    """
    lines = []
    lines.append('# Translation template for luci-app-qmodem-next')
    lines.append('# Generated automatically by extract_i18n_strings.py')
    lines.append('')
    lines.append('msgid ""')
    lines.append('msgstr ""')
    lines.append('"Content-Type: text/plain; charset=UTF-8\\n"')
    lines.append('')
    
    # Group by string to show all locations
    string_locations = {}
    for item in items:
        string = item['string']
        if string not in string_locations:
            string_locations[string] = []
        string_locations[string].append((item['file'], item['line']))
    
    # Sort by string
    for string in sorted(string_locations.keys()):
        # Add source comments
        for file_path, line_num in sorted(string_locations[string]):
            lines.append(f'#: {file_path}:{line_num}')
        lines.append(f'msgid "{escape_po_string(string)}"')
        lines.append('msgstr ""')
        lines.append('')
    
    output = '\n'.join(lines)
    
    if output_file:
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(output)
        print(f"PO template written to: {output_file}")
    else:
        print(output)

def escape_po_string(s: str) -> str:
    """Escape special characters for PO file format."""
    s = s.replace('\\', '\\\\')
    s = s.replace('"', '\\"')
    s = s.replace('\n', '\\n')
    s = s.replace('\t', '\\t')
    return s

def generate_json_template(items: List[Dict[str, any]], output_file: str = None):
    """
    Generate a JSON template file.
    
    Args:
        items: List of dictionaries with string, line, and file information
        output_file: Output file path (None for stdout)
    """
    # Group by string to show all locations
    string_locations = {}
    for item in items:
        string = item['string']
        if string not in string_locations:
            string_locations[string] = []
        string_locations[string].append((item['file'], item['line']))
    
    # Create template with comments
    template = {}
    for string in sorted(string_locations.keys()):
        # Add location info as comment (will be in _comment field)
        locations = ', '.join([f'{f}:{l}' for f, l in sorted(string_locations[string])])
        template[string] = {
            "_comment": f"Source: {locations}",
            "translation": ""
        }
    
    output = json.dumps(template, ensure_ascii=False, indent=2)
    
    if output_file:
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(output)
        print(f"JSON template written to: {output_file}")
    else:
        print(output)

def generate_txt_list(items: List[Dict[str, any]], output_file: str = None):
    """
    Generate a simple text list of strings with source comments.
    
    Args:
        items: List of dictionaries with string, line, and file information
        output_file: Output file path (None for stdout)
    """
    # Group by string to show all locations
    string_locations = {}
    for item in items:
        string = item['string']
        if string not in string_locations:
            string_locations[string] = []
        string_locations[string].append((item['file'], item['line']))
    
    lines = []
    for string in sorted(string_locations.keys()):
        # Add location comments
        for file_path, line_num in sorted(string_locations[string]):
            lines.append(f'# {file_path}:{line_num}')
        lines.append(string)
        lines.append('')
    
    output = '\n'.join(lines)
    
    if output_file:
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(output)
        print(f"String list written to: {output_file}")
    else:
        print(output)

def print_summary(items: List[Dict[str, any]]):
    """Print a summary of extracted strings."""
    print("\n" + "="*70)
    print("EXTRACTION SUMMARY")
    print("="*70)
    
    # Group by file
    file_strings = {}
    all_strings = set()
    for item in items:
        file_path = item['file']
        string = item['string']
        if file_path not in file_strings:
            file_strings[file_path] = set()
        file_strings[file_path].add(string)
        all_strings.add(string)
    
    for file_path in sorted(file_strings.keys()):
        print(f"\n{file_path}: {len(file_strings[file_path])} strings")
    
    print("\n" + "-"*70)
    print(f"Total files processed: {len(file_strings)}")
    print(f"Total unique strings: {len(all_strings)}")
    print(f"Total occurrences: {len(items)}")
    print("="*70 + "\n")

def main():
    import argparse
    
    parser = argparse.ArgumentParser(
        description='Extract translatable strings from LuCI JavaScript files and shell scripts',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Extract from default JS directory and show all strings
  %(prog)s
  
  # Extract and generate PO template
  %(prog)s --format po --output i18n_template.po
  
  # Extract from custom JS directory
  %(prog)s --js-path /path/to/resources
  
  # Extract from both JS and shell script directories
  %(prog)s --js-path luci/luci-app-qmodem-next/htdocs/luci-static/resources --sh-path application/qmodem/files/usr/share/qmodem
        """
    )
    
    parser.add_argument(
        '-d', '--directory',
        help='[Deprecated] Use --js-path instead. Directory to scan for JavaScript files'
    )
    
    parser.add_argument(
        '--js-path',
        default='luci/luci-app-qmodem-next/htdocs/luci-static/resources',
        help='Directory to scan for JavaScript files (default: %(default)s)'
    )
    
    parser.add_argument(
        '--sh-path',
        help='Directory to scan for shell script files with add_*_entry calls'
    )
    
    parser.add_argument(
        '-f', '--format',
        choices=['txt', 'json', 'po'],
        default='txt',
        help='Output format: txt (plain list), json (JSON object), po (gettext template) (default: %(default)s)'
    )
    
    parser.add_argument(
        '-o', '--output',
        help='Output file path (default: print to stdout)'
    )
    
    parser.add_argument(
        '-v', '--verbose',
        action='store_true',
        help='Show detailed information about each file'
    )
    
    parser.add_argument(
        '--no-summary',
        action='store_true',
        help='Do not print summary statistics'
    )
    
    args = parser.parse_args()
    
    # Get the script directory
    script_dir = Path(__file__).parent.absolute()
    project_root = script_dir.parent
    
    # Handle deprecated --directory argument
    js_path = args.js_path
    if args.directory:
        print("Warning: --directory is deprecated, use --js-path instead", file=sys.stderr)
        js_path = args.directory
    
    # Resolve JS directory path
    if Path(js_path).is_absolute():
        js_scan_dir = js_path
    else:
        js_scan_dir = project_root / js_path
    
    results = []
    
    # Extract strings from JavaScript files
    print(f"Scanning JavaScript directory: {js_scan_dir}", file=sys.stderr)
    js_results = scan_directory(str(js_scan_dir))
    results.extend(js_results)
    print(f"Found {len(js_results)} strings in JavaScript files", file=sys.stderr)
    
    # Extract strings from shell scripts if path is provided
    if args.sh_path:
        # Resolve shell script directory path
        if Path(args.sh_path).is_absolute():
            sh_scan_dir = args.sh_path
        else:
            sh_scan_dir = project_root / args.sh_path
        
        print(f"Scanning shell script directory: {sh_scan_dir}", file=sys.stderr)
        sh_results = scan_shell_directory(str(sh_scan_dir))
        results.extend(sh_results)
        print(f"Found {len(sh_results)} strings in shell scripts", file=sys.stderr)
    
    if not results:
        print("No translatable strings found!", file=sys.stderr)
        return 1
    
    # Print detailed results if verbose
    if args.verbose:
        # Group by file
        file_items = {}
        for item in results:
            file_path = item['file']
            if file_path not in file_items:
                file_items[file_path] = []
            file_items[file_path].append(item)
        
        for file_path in sorted(file_items.keys()):
            print(f"\n{file_path}:", file=sys.stderr)
            for item in sorted(file_items[file_path], key=lambda x: x['line']):
                print(f"  Line {item['line']}: {item['string']}", file=sys.stderr)
    
    # Generate output in requested format
    print(file=sys.stderr)  # Blank line
    if args.format == 'po':
        generate_po_template(results, args.output)
    elif args.format == 'json':
        generate_json_template(results, args.output)
    else:  # txt
        generate_txt_list(results, args.output)
    
    # Print summary
    if not args.no_summary:
        print_summary(results)
    
    return 0

if __name__ == '__main__':
    sys.exit(main())
