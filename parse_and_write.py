import os
import re
from pathlib import Path

txt_files = ["file1.txt", "file2.txt", "file3.txt", "file4.txt"]
base_dir = Path("e:/FitBuddy")

for txt_file in txt_files:
    path = base_dir / txt_file
    if not path.exists():
        continue
        
    lines = path.read_text(encoding='utf-8').splitlines()
    
    filename = None
    in_block = False
    block_ticks = ""
    content = []
    
    count = 0
    for line in lines:
        m = re.match(r"^###\s+(.+)", line)
        if m:
            in_block = False
            filename = m.group(1).strip().strip('`')
            continue
            
        m_tick = re.match(r"^(```+)", line)
        if m_tick:
            if not in_block and filename:
                in_block = True
                block_ticks = m_tick.group(1)
                content = []
                continue
            elif in_block and line.startswith(block_ticks):
                in_block = False
                
                out_path = base_dir / filename
                out_path.parent.mkdir(parents=True, exist_ok=True)
                out_path.write_text("\n".join(content) + "\n", encoding='utf-8')
                print(f"Wrote {filename}")
                count += 1
                filename = None
                continue
                
        if in_block:
            content.append(line)
            
    print(f"Finished processing {txt_file}, found {count} files.")
