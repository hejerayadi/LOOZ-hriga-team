"""Writes the function code of src/*.js into flows.json (the code lives in src/ so it
can be read, reviewed and tested outside Node-RED: test/flow_test.js), and adds the
frost-scenario switch to the Simulation group of the dashboard (once).

    python tools/build_flows.py        (Node-RED stopped; then start it again)
"""
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
FLOWS = HERE / "flows.json"
SOURCES = {                       # node id in flows.json -> source file
    "d39eb3047a3ea65d": "simulator.js",
    "0b74ec7d74f187af": "gateway.js",
    "5753aa8ae37577f0": "rules.js",
    "a1c0de5000000002": "codes.js",
}
TAB = "e36a9607f46cef68"
GROUP = "712fa51631882c9c"        # dashboard group "Simulation"

NEW_NODES = [
    {"id": "a1c0de5000000010", "type": "comment", "z": TAB,
     "name": "Scénario « nuit de gel en floraison » (IA gel) : interrupteur du dashboard ou LOOZ_SCENARIO=frost dans .env",
     "info": "", "x": 300, "y": 700, "wires": []},
    {"id": "a1c0de5000000011", "type": "ui-switch", "z": TAB, "name": "Interrupteur scénario gel",
     "label": "Scénario : nuit de gel (floraison)", "group": GROUP, "order": 4, "width": "6", "height": "1",
     "passthru": False, "decouple": False, "topic": "scenario", "topicType": "str", "style": "", "className": "",
     "layout": "row-spread", "clickableArea": "switch", "onvalue": "frost", "onvalueType": "str", "onicon": "",
     "oncolor": "", "offvalue": "summer", "offvalueType": "str", "officon": "", "offcolor": "",
     "x": 190, "y": 760, "wires": [["a1c0de5000000012"]]},
    {"id": "a1c0de5000000012", "type": "change", "z": TAB, "name": "flow.scenario ← payload",
     "rules": [{"t": "set", "p": "scenario", "pt": "flow", "to": "payload", "tot": "msg"}],
     "action": "", "property": "", "from": "", "to": "", "reg": False, "x": 470, "y": 760, "wires": [[]]},
    {"id": "a1c0de5000000013", "type": "inject", "z": TAB, "name": "Au démarrage : scénario en cours",
     "props": [], "repeat": "", "crontab": "", "once": True, "onceDelay": 0.2, "topic": "",
     "x": 200, "y": 820, "wires": [["a1c0de5000000014"]]},
    {"id": "a1c0de5000000014", "type": "function", "z": TAB, "name": "Scénario en cours → interrupteur",
     "func": "// Montre sur le dashboard le scénario gardé en mémoire (ou celui de .env).\n"
             "const s = flow.get(\"scenario\") || env.get(\"LOOZ_SCENARIO\") || \"summer\";\n"
             "return { payload: s === \"frost\" ? \"frost\" : \"summer\" };",
     "outputs": 1, "timeout": 0, "noerr": 0, "initialize": "", "finalize": "", "libs": [],
     "x": 470, "y": 820, "wires": [["a1c0de5000000011"]]},
]


def main() -> int:
    flows = json.loads(FLOWS.read_text(encoding="utf-8"))
    by_id = {n["id"]: n for n in flows}
    for nid, src in SOURCES.items():
        by_id[nid]["func"] = (HERE / "src" / src).read_text(encoding="utf-8")
    for node in NEW_NODES:
        if node["id"] in by_id:
            by_id[node["id"]].update(node)
        else:
            flows.append(node)
    FLOWS.write_text(json.dumps(flows, ensure_ascii=False, indent=4) + "\n", encoding="utf-8")
    print(f"flows.json: {len(SOURCES)} functions written, {len(NEW_NODES)} scenario nodes")
    return 0


if __name__ == "__main__":
    sys.exit(main())
