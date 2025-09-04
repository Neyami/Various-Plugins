# written by ChatGPT
# if material hasn't been defined for an entity, it will be set to 0 (glass)

import os
import re

def process_ent_file(filepath: str):
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()

    entities = re.findall(r"\{[^}]*\}", content, re.DOTALL)
    materials = []

    for ent in entities:
        if '"classname" "func_breakable"' in ent or '"classname" "func_pushable"' in ent:
            model_match = re.search(r'"model"\s+"([^"]+)"', ent)
            material_match = re.search(r'"material"\s+"([^"]+)"', ent)

            if model_match:
                model = model_match.group(1)
                material = material_match.group(1) if material_match else "0"
                materials.append(f'{model} {material}')

    if materials:
        outpath = os.path.splitext(filepath)[0] + ".mat"
        with open(outpath, "w", encoding="utf-8") as f:
            f.write("\n".join(materials))
        print(f"Written: {outpath}")
    else:
        print(f"No func_breakable/pushable found in {filepath}")

def main():
    for filename in os.listdir("."):
        if filename.lower().endswith(".ent"):
            process_ent_file(filename)

if __name__ == "__main__":
    main()
