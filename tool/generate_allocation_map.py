"""Regenerate the public-domain offline map using only Python's standard library."""
import hashlib
import json
from pathlib import Path
from urllib.request import urlopen

REVISION = "ca96624a56bd078437bca8184e78163e5039ad19"
SOURCE = f"https://raw.githubusercontent.com/nvkelso/natural-earth-vector/{REVISION}/geojson/ne_110m_admin_0_countries.geojson"

def generate(raw):
    features = []
    for feature in json.loads(raw)["features"]:
        properties = feature["properties"]
        code = properties.get("ISO_A2_EH") or properties["ISO_A2"]
        if code == "-99":
            code = properties["ADM0_A3"]  # Preserve source regions; do not invent ISO codes.
        polygons = feature["geometry"]["coordinates"]
        if feature["geometry"]["type"] == "Polygon":
            polygons = [polygons]
        features.append({"id": code, "name": properties["NAME_EN"],
            "polygons": [[[[round(x, 1), round(y, 1)] for x, y in ring]
                for ring in polygon] for polygon in polygons]})
    return (json.dumps(features, separators=(",", ":"), ensure_ascii=True) + "\n").encode()

if __name__ == "__main__":
    raw = urlopen(SOURCE).read()
    target = Path(__file__).resolve().parents[1] / "assets/maps/world_110m.json"
    target.parent.mkdir(parents=True, exist_ok=True)
    result = generate(raw)
    target.write_bytes(result)
    print(f"{len(result)} bytes; SHA256 {hashlib.sha256(result).hexdigest()}")
