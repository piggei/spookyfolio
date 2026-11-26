# Offline allocation map

Country outlines from Natural Earth, 1:110m, public domain.

- [Terms of use](https://www.naturalearthdata.com/about/terms-of-use/).
- Source: `nvkelso/natural-earth-vector`, revision `ca96624a56bd078437bca8184e78163e5039ad19`, `geojson/ne_110m_admin_0_countries.geojson`.
- Source size: 838,726 bytes. Bundled outline asset: 143250 bytes (about 140 KiB), 177 features.
- Bundled SHA256: `83fa0a9f28a411a580326751671625d926df5e57d2a5b11bc7a1dc21313ddffe`.

Only identifiers, English names and polygon rings are retained; longitude and latitude are rounded to 0.1 degree. ISO_A2_EH identifies countries; source non-ISO regions retain ADM0_A3 identifiers. No financial country classifications or exposure values are generated from geometry. Small countries without outlines remain explicitly unmapped in the UI. The generalized boundaries are for portfolio visualization, not authoritative boundary or navigation data.

Regenerate from the pinned source with `python3 tool/generate_allocation_map.py`. Updating the source revision is a deliberate maintenance step requiring review of country identifiers, size and rendered outlines. No map services, credentials, runtime network access, SDK or additional Flutter dependency is needed. Natural Earth data remains public domain; this notice does not change the application's license.
