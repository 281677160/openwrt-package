#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Auto-translate i18n strings using LLM API
"""

import os
import sys
import json
import argparse
import subprocess
from pathlib import Path

def read_po_file_as_example(po_file_path: str) -> str:
    """Read PO file and return as example text"""
    try:
        with open(po_file_path, 'r', encoding='utf-8') as f:
            return f.read()
    except FileNotFoundError:
        print(f"Warning: Example PO file not found: {po_file_path}")
        return ""

def parse_po_file_translations(po_file_path: str) -> set:
    """Parse PO file and return a set of keys that have translations"""
    translated_keys = set()
    
    try:
        with open(po_file_path, 'r', encoding='utf-8') as f:
            content = f.read()
            
        # Simple PO file parser
        lines = content.split('\n')
        current_msgid = None
        
        for line in lines:
            line = line.strip()
            
            if line.startswith('msgid "'):
                # Extract msgid
                msgid_value = line[7:-1]  # Remove 'msgid "' and closing '"'
                current_msgid = unescape_po_string(msgid_value)
                
            elif line.startswith('msgstr "') and current_msgid:
                # Extract msgstr
                msgstr_value = line[8:-1]  # Remove 'msgstr "' and closing '"'
                msgstr_unescaped = unescape_po_string(msgstr_value)
                
                # Only add to set if msgstr is not empty and not same as msgid
                if msgstr_unescaped:
                    translated_keys.add(current_msgid)
                
                current_msgid = None
        
        return translated_keys
        
    except FileNotFoundError:
        print(f"Warning: Exclude keys file not found: {po_file_path}")
        return set()
    except Exception as e:
        print(f"Warning: Error parsing exclude keys file: {e}")
        return set()

def unescape_po_string(s: str) -> str:
    """Unescape special characters from PO file format"""
    s = s.replace('\\n', '\n')
    s = s.replace('\\t', '\t')
    s = s.replace('\\"', '"')
    s = s.replace('\\\\', '\\')
    return s

def extract_strings_as_json(sh_path: str, js_path: str) -> dict:
    """Extract i18n strings using extract_i18n_strings.py"""
    cmd = [
        'python3', 
        'scripts/extract_i18n_strings.py',
        '--sh-path', sh_path,
        '--js-path', js_path,
        '--format', 'json',
        '--output', 'strings.json'
    ]
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        
        with open('strings.json', 'r', encoding='utf-8') as f:
            return json.load(f)
    except subprocess.CalledProcessError as e:
        print(f"Error extracting strings: {e}")
        print(f"stderr: {e.stderr}")
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"Error parsing JSON output: {e}")
        sys.exit(1)

def translate_with_llm(strings_data: dict, api_base: str, api_key: str, model: str, target_lang: str = "zh_Hans", example_po: str = "") -> dict:
    """Translate strings using LLM API"""
    import requests
    
    # Prepare the strings list for translation
    # strings_data is a dict where keys are the strings to translate
    strings_list = list(strings_data.keys())
    
    # Define prompts for different target languages
    prompts = {
        "zh_Hans": """这是一个4G/5G CPE 管理插件，请根据需要的语言和语境，按json格式返回翻译内容

目标语言: 简体中文

翻译示例（参考风格和术语）:
{example}

需要翻译的字符串（JSON格式）:
{strings}

请返回JSON格式的翻译结果，格式如下：
{{
  "原文1": "译文1",
  "原文2": "译文2",
  ...
}}

注意事项：
1. 保持技术术语的准确性（如 Modem, AT Port, PDP, DNS等）
2. 保持界面文本的简洁性
3. 使用与示例一致的翻译风格
4. 保留原文中的HTML标签、格式符号等
5. 只返回JSON格式的翻译结果，不要添加其他说明
""",
        "zh_Hant": """這是一個4G/5G CPE 管理插件，請根據需要的語言和語境，按json格式返回翻譯內容

目標語言: 繁體中文

翻譯示例（參考風格和術語）:
{example}

需要翻譯的字符串（JSON格式）:
{strings}

請返回JSON格式的翻譯結果，格式如下：
{{
  "原文1": "譯文1",
  "原文2": "譯文2",
  ...
}}

注意事項：
1. 保持技術術語的準確性（如 Modem, AT Port, PDP, DNS等）
2. 保持界面文本的簡潔性
3. 使用與示例一致的翻譯風格
4. 保留原文中的HTML標籤、格式符號等
5. 只返回JSON格式的翻譯結果，不要添加其他說明
""",
        "en": """This is a 4G/5G CPE management plugin. Please translate the strings to the target language and return the result in JSON format.

Target language: English

Translation examples (for reference of style and terminology):
{example}

Strings to translate (JSON format):
{strings}

Please return the translation result in JSON format as follows:
{{
  "source1": "translation1",
  "source2": "translation2",
  ...
}}

Important notes:
1. Keep technical terms accurate (e.g., Modem, AT Port, PDP, DNS, etc.)
2. Keep UI text concise
3. Use translation style consistent with the examples
4. Preserve HTML tags and format symbols from the original text
5. Return only the JSON translation result without additional explanations
""",
        "ja": """これは4G/5G CPE管理プラグインです。必要な言語とコンテキストに従って、json形式で翻訳内容を返してください

対象言語: 日本語

翻訳例（スタイルと用語の参考）:
{example}

翻訳が必要な文字列（JSON形式）:
{strings}

次の形式でJSON形式の翻訳結果を返してください：
{{
  "原文1": "訳文1",
  "原文2": "訳文2",
  ...
}}

注意事項：
1. 技術用語の正確性を保つ（Modem、AT Port、PDP、DNSなど）
2. インターフェーステキストの簡潔性を保つ
3. 例と一致した翻訳スタイルを使用する
4. 原文のHTMLタグ、書式記号などを保持する
5. JSON形式の翻訳結果のみを返し、他の説明を追加しないでください
""",
        "ko": """이것은 4G/5G CPE 관리 플러그인입니다. 필요한 언어와 맥락에 따라 json 형식으로 번역 내용을 반환해주세요

대상 언어: 한국어

번역 예시 (스타일 및 용어 참고):
{example}

번역이 필요한 문자열 (JSON 형식):
{strings}

다음 형식으로 JSON 형식의 번역 결과를 반환해주세요:
{{
  "원문1": "번역1",
  "원문2": "번역2",
  ...
}}

주의사항:
1. 기술 용어의 정확성 유지 (Modem, AT Port, PDP, DNS 등)
2. 인터페이스 텍스트의 간결성 유지
3. 예시와 일관된 번역 스타일 사용
4. 원문의 HTML 태그, 형식 기호 등 보존
5. JSON 형식의 번역 결과만 반환하고 다른 설명 추가하지 않기
""",
    }
    
    # Get prompt template for target language, fallback to English
    prompt_template = prompts.get(target_lang, prompts["en"])
    
    # Build the prompt
    prompt = prompt_template.format(
        example=example_po[:3000] if example_po else "无示例" if target_lang.startswith("zh") else "No example",
        strings=json.dumps(strings_list, ensure_ascii=False, indent=2)
    )

    # Call LLM API
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {api_key}"
    }
    
    payload = {
        "model": model,
        "messages": [
            {
                "role": "user",
                "content": prompt
            }
        ],
        "temperature": 0.3,
    }
    
    try:
        response = requests.post(
            f"{api_base}/chat/completions",
            headers=headers,
            json=payload,
            timeout=120
        )
        response.raise_for_status()
        
        result = response.json()
        content = result['choices'][0]['message']['content']
        
        # Try to extract JSON from the response
        # Sometimes LLM wraps JSON in markdown code blocks
        if "```json" in content:
            content = content.split("```json")[1].split("```")[0].strip()
        elif "```" in content:
            content = content.split("```")[1].split("```")[0].strip()
        
        translations = json.loads(content)
        return translations
        
    except requests.exceptions.RequestException as e:
        print(f"Error calling LLM API: {e}")
        if hasattr(e, 'response') and e.response is not None:
            print(f"Response: {e.response.text}")
        sys.exit(1)
    except (json.JSONDecodeError, KeyError) as e:
        print(f"Error parsing LLM response: {e}")
        print(f"Response content: {content if 'content' in locals() else 'N/A'}")
        sys.exit(1)

def generate_po_file(strings_data: dict, translations: dict, output_path: str):
    """Generate PO file with translations"""
    
    po_content = []
    
    # strings_data is a dict where keys are the original strings
    for original, metadata in strings_data.items():
        translated = translations.get(original, original)
        
        # Add location comment from metadata
        comment = metadata.get('_comment', '')
        if comment:
            po_content.append(f"# {comment}")
        
        # Add msgid and msgstr
        po_content.append(f'msgid "{escape_po_string(original)}"')
        po_content.append(f'msgstr "{escape_po_string(translated)}"')
        po_content.append("")  # Empty line between entries
    
    # Write to file
    output_file = Path(output_path)
    output_file.parent.mkdir(parents=True, exist_ok=True)
    po_content.append("")  # Append newline at end of output file
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write('\n'.join(po_content))
    
    print(f"Translation saved to: {output_path}")

def escape_po_string(s: str) -> str:
    """Escape special characters for PO file format"""
    s = s.replace('\\', '\\\\')
    s = s.replace('"', '\\"')
    s = s.replace('\n', '\\n')
    s = s.replace('\t', '\\t')
    return s

def main():
    parser = argparse.ArgumentParser(
        description='Auto-translate i18n strings using LLM API'
    )
    
    parser.add_argument(
        '--api-base',
        required=True,
        help='LLM API base URL (e.g., https://api.openai.com/v1)'
    )
    
    parser.add_argument(
        '--api-key',
        required=True,
        help='LLM API key'
    )
    
    parser.add_argument(
        '--model',
        required=True,
        help='LLM model name (e.g., gpt-4, claude-3-sonnet)'
    )
    
    parser.add_argument(
        '--sh-path',
        default='application/qmodem/files/usr/share/qmodem',
        help='Path to shell scripts directory'
    )
    
    parser.add_argument(
        '--js-path',
        default='luci/luci-app-qmodem-next/htdocs/luci-static/resources',
        help='Path to JavaScript files directory'
    )
    
    parser.add_argument(
        '--target-lang',
        default='zh_Hans',
        help='Target language code (default: zh_Hans)'
    )
    
    parser.add_argument(
        '--example-po',
        default='luci/luci-app-qmodem/po/zh_Hans/qmodem.po',
        help='Path to example PO file for translation reference'
    )
    
    parser.add_argument(
        '--output',
        default='luci/luci-app-qmodem-next/po/zh_Hans/qmodem-next.po',
        help='Output PO file path'
    )
    
    parser.add_argument(
        '--exclude-keys',
        help='Path to PO file containing existing translations to exclude from translation'
    )
    
    args = parser.parse_args()
    
    print("Step 1: Extracting i18n strings...")
    strings_data = extract_strings_as_json(args.sh_path, args.js_path)
    print(f"Extracted {len(strings_data)} strings")
    
    # Exclude keys that already have translations
    if args.exclude_keys:
        print(f"\nStep 2: Excluding existing translations from {args.exclude_keys}...")
        excluded_keys = parse_po_file_translations(args.exclude_keys)
        print(f"Found {len(excluded_keys)} existing translations to exclude")
        
        # Filter out excluded keys
        original_count = len(strings_data)
        strings_data = {k: v for k, v in strings_data.items() if k not in excluded_keys}
        print(f"Filtered {original_count - len(strings_data)} strings, {len(strings_data)} remaining for translation")
    
    print(f"\nStep {'3' if args.exclude_keys else '2'}: Reading example PO file...")
    example_po = read_po_file_as_example(args.example_po)
    
    print(f"\nStep {'4' if args.exclude_keys else '3'}: Translating with LLM API...")
    translations = translate_with_llm(
        strings_data,
        args.api_base,
        args.api_key,
        args.model,
        args.target_lang,
        example_po
    )
    print(f"Received {len(translations)} translations")
    
    print(f"\nStep {'5' if args.exclude_keys else '4'}: Generating PO file...")
    generate_po_file(strings_data, translations, args.output)
    
    print("\n✓ Translation completed successfully!")

if __name__ == '__main__':
    main()
