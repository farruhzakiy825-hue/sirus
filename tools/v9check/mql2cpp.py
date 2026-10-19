import re, sys, os
root=sys.argv[1]; main=sys.argv[2]; out=sys.argv[3]
def inline(path):
    txt=open(path,encoding='utf-8-sig').read()
    res=[]
    for line in txt.splitlines():
        m=re.match(r'\s*#include\s+"([^"]+)"',line)
        if m:
            res.append(inline(os.path.join(root,m.group(1))))
        else:
            res.append(line)
    return "\n".join(res)
s=inline(os.path.join(root,main))
s=re.sub(r'^\s*#property.*$','',s,flags=re.M)
s=re.sub(r'^\s*input\s+group.*$','',s,flags=re.M)
s=re.sub(r'^(\s*)input\s+','\\1const ',s,flags=re.M)
s=re.sub(r"C'(\d+),(\d+),(\d+)'",r'RGBc(\1,\2,\3)',s)
# dynamic arrays:  Type name[];  -> MqlArray<Type> name;
s=re.sub(r'\b(MqlRates|double|int|datetime|string)\s+(\w+)\[\];',r'MqlArray<\1> \2;',s)
s=re.sub(r'\b(const\s+)?(MqlRates|double|int|datetime|string)\s*&\s*(\w+)\[\]',lambda m:(m.group(1) or '')+'MqlArray<'+m.group(2)+'> &'+m.group(3),s)
open(out,'w').write('#include "mql5shim.h"\n'+s+'\n')
