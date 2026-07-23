#!/bin/sh
# Normalizes whatever corporate root CA export was dropped into certs/ —
# DER-binary (.cer/.der), Base64/PEM (.cer/.pem/.crt), or PKCS#7 (.p7b/.p7c)
# — into PEM .crt files, since update-ca-certificates only scans for *.crt
# and expects PEM content. Run at build time from the Dockerfile, right
# before `update-ca-certificates`. Safe no-op when certs/ is empty.
set -eu
cd "$(dirname "$0")"
self=$(basename "$0")

for f in *; do
  [ -f "$f" ] || continue
  case "$f" in
    .gitkeep|README.md|"$self") continue ;;
  esac

  out="${f%.*}.crt"
  tmp="$out.tmp"

  if openssl x509 -in "$f" -inform PEM -out "$tmp" 2>/dev/null \
    || openssl x509 -in "$f" -inform DER -out "$tmp" 2>/dev/null \
    || openssl pkcs7 -in "$f" -inform PEM -print_certs -out "$tmp" 2>/dev/null \
    || openssl pkcs7 -in "$f" -inform DER -print_certs -out "$tmp" 2>/dev/null; then
    mv "$tmp" "$out"
    [ "$f" = "$out" ] || rm -f "$f"
  else
    echo "warning: could not parse certificate file '$f' (unsupported format), skipping" >&2
    rm -f "$tmp"
  fi
done
