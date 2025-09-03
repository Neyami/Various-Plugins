# written by ChatGPT

import os
import sys
import re

def extract_materials(filepath: str):
    if not os.path.isfile(filepath):
        print(f"Error: File '{filepath}' not found.")
        return

    with open(filepath, 'r') as f:
        content = f.read()

    # Pattern to match each entity block
    entities = re.findall(r'\{[^}]*\}', content, re.DOTALL)

    output_lines = []

    for entity in entities:
        classname_match = re.search(r'"classname"\s+"(func_breakable|func_pushable)"', entity)
        model_match = re.search(r'"model"\s+"([^"]+)"', entity)
        material_match = re.search(r'"material"\s+"([^"]+)"', entity)

        if classname_match and model_match and material_match:
            model = model_match.group(1)
            material = material_match.group(1)
            output_lines.append(f'{model} {material}')

    if not output_lines:
        print("No matching entries found.")
        return

    output_file = os.path.splitext(filepath)[0] + ".mat"
    with open(output_file, 'w') as out:
        out.write("\n".join(output_lines))

    print(f"Materials extracted to {output_file}")

if __name__ == '__main__':
    if len(sys.argv) != 2:
        print("Usage: python extract_materials.py <ripent_file.ent>")
    else:
        extract_materials(sys.argv[1])
