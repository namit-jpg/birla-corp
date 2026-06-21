import json, sys, subprocess, os

RAW="/home/namit/birla-corp/epc-discovery/raw"

def describe(obj):
    path=f"{RAW}/{obj}.json"
    if not os.path.exists(path):
        r=subprocess.run(["sf","sobject","describe","-s",obj,"-o","epc","--json"],
                         capture_output=True,text=True)
        open(path,"w").write(r.stdout)
    try:
        d=json.load(open(path))["result"]
    except Exception as e:
        return f"ERROR {obj}: {e}"
    out=[]
    out.append(f"### {d.get('label')} (`{obj}`)")
    flags=[]
    if d.get('custom'): flags.append('custom')
    out.append(f"- keyPrefix: {d.get('keyPrefix')}")
    # record types
    rts=[rt['name'] for rt in d.get('recordTypeInfos',[]) if not rt.get('master')]
    if rts: out.append(f"- Record Types: {', '.join(rts)}")
    out.append("")
    out.append("| Field | Label | Type | Ref/Picklist | Req |")
    out.append("|---|---|---|---|---|")
    for f in d.get('fields',[]):
        nm=f['name']
        # only custom fields + key standard
        if not (nm.endswith('__c') or nm in ('Name','OwnerId','RecordTypeId')):
            continue
        t=f['type']
        extra=""
        if t=='reference':
            extra=",".join(f.get('referenceTo',[]))
        elif t in ('picklist','multipicklist'):
            vals=[v['value'] for v in f.get('picklistValues',[]) if v.get('active')]
            extra="; ".join(vals[:25])
            if len(vals)>25: extra+=f" …(+{len(vals)-25})"
        elif t in ('double','currency','percent'):
            extra=f"({f.get('precision')},{f.get('scale')})"
        elif t in ('string','textarea'):
            extra=f"len {f.get('length')}"
        elif t=='formula' or f.get('calculatedFormula'):
            extra="formula"
        req="Y" if (not f.get('nillable') and f.get('createable') and t!='boolean') else ""
        lbl=f.get('label','')
        out.append(f"| {nm} | {lbl} | {t} | {extra} | {req} |")
    out.append("")
    return "\n".join(out)

if __name__=="__main__":
    for o in sys.argv[1:]:
        print(describe(o))
