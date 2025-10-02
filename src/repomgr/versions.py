import re
from typing import List, Dict, Tuple


def is_version(version_string):
    pattern = r'^v\d+\.\d+\.\d+$'
    return bool(re.match(pattern, version_string))

def get_latest_versions(versions: List[str]) -> List[str]:
    latest_patches: Dict[Tuple[int, int], Tuple[int, str]] = {}

    pattern = r'^v(\d+)\.(\d+)\.(\d+)$'

    for version in versions:
        match = re.match(pattern, version)
        if match:
            major = int(match.group(1))
            minor = int(match.group(2))
            patch = int(match.group(3))

            key = (major, minor)

            if key not in latest_patches or patch > latest_patches[key][0]:
                latest_patches[key] = (patch, version)

    result = [version for _, version in latest_patches.values()]
    result.sort(key=lambda v: [int(x) for x in re.match(r'^v(\d+)\.(\d+)\.(\d+)$', v).groups()])

    return result
