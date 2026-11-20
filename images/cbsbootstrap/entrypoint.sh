#!/usr/bin/env bash
# One-shot Couchbase bootstrap for Docker Compose and Kubernetes init containers.
#
# Uses the Go cbctl CLI (https://github.com/mminichino/cbctl, >=0.7.0).
#
# Two modes:
#   1. Manifest: a cbctl/v1 `kind: CouchbaseServer` YAML definition applied with
#      `cbctl apply -f`. Selected by CBS_MANIFEST (file or directory),
#      CBS_MANIFEST_YAML (inline YAML), or a manifest mounted at /manifest
#      (couchbase.yaml, couchbase.yml, or a directory of *.yaml / *.yml files).
#   2. Environment: CBS_* variables drive `cbctl cluster/bucket/scope/collection`.
set -euo pipefail

log() {
  echo "[cbsbootstrap] $*"
}

die() {
  echo "[cbsbootstrap] ERROR: $*" >&2
  exit 1
}

is_truthy() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

extract_host() {
  # HOST[=SERVICES][@RAM][#ALTERNATE[;PORTS]]
  local spec="$1"
  local host_part="${spec%%#*}"
  host_part="${host_part%%@*}"
  echo "${host_part%%=*}"
}

# Return the #ALTERNATE[;PORTS] fragment from a node spec, if present.
extract_alternate_fragment() {
  local spec="$1"
  if [[ "${spec}" != *"#"* ]]; then
    echo ""
    return
  fi
  echo "${spec#*#}"
}

extract_alternate_host() {
  local fragment="$1"
  [[ -z "${fragment}" ]] && { echo ""; return; }
  echo "${fragment%%;*}"
}

# Build an alternate-address fragment: HOST or HOST;service:port,...
compose_alternate() {
  local address="$1"
  local ports="${2:-}"
  if [[ -z "${address}" ]]; then
    echo ""
    return
  fi
  if [[ -n "${ports}" && "${address}" != *";"* ]]; then
    echo "${address};${ports}"
  else
    echo "${address}"
  fi
}

# Append #ALTERNATE to a node spec when missing.
with_alternate() {
  local spec="$1"
  local alternate="$2"
  if [[ -z "${alternate}" || "${spec}" == *"#"* ]]; then
    echo "${spec}"
  else
    echo "${spec}#${alternate}"
  fi
}

# ---------------------------------------------------------------------------
# Manifest mode: cbctl apply -f (CouchbaseServer YAML definition)
# ---------------------------------------------------------------------------
CBS_MANIFEST="${CBS_MANIFEST:-}"
CBS_MANIFEST_YAML="${CBS_MANIFEST_YAML:-}"
CBS_MANIFEST_DRY_RUN="${CBS_MANIFEST_DRY_RUN:-false}"

if [[ -n "${CBS_MANIFEST}" && -n "${CBS_MANIFEST_YAML}" ]]; then
  die "Set only one of CBS_MANIFEST and CBS_MANIFEST_YAML"
fi

if [[ -z "${CBS_MANIFEST}" && -z "${CBS_MANIFEST_YAML}" ]]; then
  for candidate in /manifest/couchbase.yaml /manifest/couchbase.yml /manifest; do
    if [[ -f "${candidate}" ]]; then
      CBS_MANIFEST="${candidate}"
      break
    elif [[ -d "${candidate}" ]] && compgen -G "${candidate}/*.y*ml" > /dev/null; then
      CBS_MANIFEST="${candidate}"
      break
    fi
  done
fi

if [[ -n "${CBS_MANIFEST}" || -n "${CBS_MANIFEST_YAML}" ]]; then
  apply_args=(apply)
  if is_truthy "${CBS_MANIFEST_DRY_RUN}"; then
    apply_args+=(--dry-run)
  fi

  # Manifest passwords are ${VAR}, ${file:PATH} or ${base64:VALUE} references,
  # so reference CBS_PASSWORD (or a mounted secret file) rather than a literal.
  if [[ -n "${CBS_MANIFEST_YAML}" ]]; then
    log "Applying CouchbaseServer manifest from CBS_MANIFEST_YAML"
    printf '%s\n' "${CBS_MANIFEST_YAML}" | cbctl "${apply_args[@]}" -f -
  else
    [[ -e "${CBS_MANIFEST}" ]] || die "CBS_MANIFEST '${CBS_MANIFEST}' does not exist"
    log "Applying CouchbaseServer manifest '${CBS_MANIFEST}'"
    cbctl "${apply_args[@]}" -f "${CBS_MANIFEST}"
  fi

  log "Bootstrap complete"
  exit 0
fi

CBS_USERNAME="${CBS_USERNAME:-Administrator}"
CBS_PASSWORD="${CBS_PASSWORD:-password}"
CBS_SSL="${CBS_SSL:-false}"
CBS_SERVICES="${CBS_SERVICES:-data,index,query,fts}"
CBS_RAM="${CBS_RAM:-4}"
CBS_CREATE_CLUSTER="${CBS_CREATE_CLUSTER:-true}"
CBS_BUCKET="${CBS_BUCKET:-}"
CBS_SCOPE="${CBS_SCOPE:-}"
CBS_COLLECTION="${CBS_COLLECTION:-}"
CBS_IMPORT_KEYSPACE="${CBS_IMPORT_KEYSPACE:-}"
CBS_BUCKET_QUOTA="${CBS_BUCKET_QUOTA:-128}"
CBS_BUCKET_REPLICAS="${CBS_BUCKET_REPLICAS:-0}"
# Single-node alternate address (cbctl --alternate-address / #ALTERNATE).
# Value: HOST or HOST;kv:9000,n1ql:9050,...
CBS_ALTERNATE_ADDRESS="${CBS_ALTERNATE_ADDRESS:-}"
CBS_ALTERNATE_PORTS="${CBS_ALTERNATE_PORTS:-}"

nodes=()

if [[ -n "${CBS_NODES:-}" ]]; then
  # Prefer | as node separator so #ALTERNATE;ports can use semicolons.
  # Whitespace separation is also supported when | is absent.
  if [[ "${CBS_NODES}" == *"|"* ]]; then
    IFS='|' read -r -a nodes <<< "${CBS_NODES}"
    for i in "${!nodes[@]}"; do
      nodes[$i]="$(echo -n "${nodes[$i]}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    done
    trimmed=()
    for spec in "${nodes[@]}"; do
      [[ -n "${spec}" ]] && trimmed+=("${spec}")
    done
    nodes=("${trimmed[@]}")
  else
    # shellcheck disable=SC2206
    nodes=(${CBS_NODES})
  fi
elif [[ -n "${CBS_HOST:-}" ]]; then
  nodes=("${CBS_HOST}")
else
  i=0
  while true; do
    varname="CBS_NODE_${i}"
    value="${!varname:-}"
    [[ -z "${value}" ]] && break
    nodes+=("${value}")
    i=$((i + 1))
  done
fi

((${#nodes[@]} > 0)) || die \
  "Set CBS_HOST, CBS_NODES, or CBS_NODE_0..N to the Couchbase node(s) to bootstrap"

# Attach per-node alternates from CBS_NODE_i_ALTERNATE[+_PORTS] when not already in the spec.
for i in "${!nodes[@]}"; do
  alt_var="CBS_NODE_${i}_ALTERNATE"
  ports_var="CBS_NODE_${i}_ALTERNATE_PORTS"
  alt_fragment="$(compose_alternate "${!alt_var:-}" "${!ports_var:-}")"
  nodes[$i]="$(with_alternate "${nodes[$i]}" "${alt_fragment}")"
done

# Apply cluster-level CBS_ALTERNATE_* to node 0 when not already set on that node.
alt_fragment="$(compose_alternate "${CBS_ALTERNATE_ADDRESS}" "${CBS_ALTERNATE_PORTS}")"
if [[ -n "${alt_fragment}" ]]; then
  nodes[0]="$(with_alternate "${nodes[0]}" "${alt_fragment}")"
fi

if [[ -n "${CBS_SCOPE}" && -z "${CBS_BUCKET}" ]]; then
  die "CBS_SCOPE requires CBS_BUCKET"
fi
if [[ -n "${CBS_COLLECTION}" && ( -z "${CBS_BUCKET}" || -z "${CBS_SCOPE}" ) ]]; then
  die "CBS_COLLECTION requires CBS_BUCKET and CBS_SCOPE"
fi

if is_truthy "${CBS_SSL}"; then
  ssl_flags=(--ssl)
else
  ssl_flags=(--no-ssl)
fi

use_ext_api=false
for spec in "${nodes[@]}"; do
  if [[ -n "$(extract_alternate_fragment "${spec}")" ]]; then
    use_ext_api=true
    break
  fi
done

# Prefer alternate address for follow-on cbctl calls when configured.
api_host="$(extract_host "${nodes[0]}")"
alt0="$(extract_alternate_host "$(extract_alternate_fragment "${nodes[0]}")")"
if [[ -n "${alt0}" ]]; then
  api_host="${alt0}"
fi

common_auth=(
  --username "${CBS_USERNAME}"
  --password "${CBS_PASSWORD}"
  "${ssl_flags[@]}"
)

if is_truthy "${CBS_CREATE_CLUSTER}"; then
  cluster_args=(
    cluster create
    --services "${CBS_SERVICES}"
    --ram "${CBS_RAM}"
    "${common_auth[@]}"
  )

  if ((${#nodes[@]} == 1)) && [[ "${nodes[0]}" != *"="* && "${nodes[0]}" != *"@"* && "${nodes[0]}" != *"#"* ]]; then
    cluster_args+=(--host "${nodes[0]}")
  else
    for spec in "${nodes[@]}"; do
      cluster_args+=(--node "${spec}")
    done
  fi

  if [[ "${use_ext_api}" == true ]]; then
    cluster_args+=(--ext-api)
  fi

  log "Creating cluster on: ${nodes[*]}"
  cbctl "${cluster_args[@]}"
else
  log "Skipping cluster create (CBS_CREATE_CLUSTER=${CBS_CREATE_CLUSTER})"
fi

if [[ -n "${CBS_BUCKET}" ]]; then
  log "Creating bucket '${CBS_BUCKET}' (quota=${CBS_BUCKET_QUOTA}MiB replicas=${CBS_BUCKET_REPLICAS})"
  cbctl bucket create "${CBS_BUCKET}" \
    --host "${api_host}" \
    --quota "${CBS_BUCKET_QUOTA}" \
    --replicas "${CBS_BUCKET_REPLICAS}" \
    "${common_auth[@]}"
fi

if [[ -n "${CBS_SCOPE}" ]]; then
  log "Creating scope '${CBS_SCOPE}' in bucket '${CBS_BUCKET}'"
  cbctl scope create "${CBS_SCOPE}" \
    --bucket "${CBS_BUCKET}" \
    --host "${api_host}" \
    "${common_auth[@]}"
fi

if [[ -n "${CBS_COLLECTION}" ]]; then
  log "Creating collection '${CBS_COLLECTION}' in ${CBS_BUCKET}.${CBS_SCOPE}"
  cbctl collection create "${CBS_COLLECTION}" \
    --bucket "${CBS_BUCKET}" \
    --scope "${CBS_SCOPE}" \
    --host "${api_host}" \
    "${common_auth[@]}"
fi

if [[ -f /import/data.json ]]; then
  [[ -n "${CBS_IMPORT_KEYSPACE}" ]] || die \
    "CBS_IMPORT_KEYSPACE is required when /import/data.json exists"
  log "Importing '/import/data.json' into '${CBS_IMPORT_KEYSPACE}'"
  cbctl import /import/data.json "${CBS_IMPORT_KEYSPACE}" \
    --host "${api_host}" \
    "${common_auth[@]}"
fi

log "Bootstrap complete"
exit 0
