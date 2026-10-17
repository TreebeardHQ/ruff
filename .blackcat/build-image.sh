#!/bin/sh
# Build the template's bootstrap image without Docker: Ubuntu plus the boot
# scripts. All heavy work happens inside the Blackcat template build VM.
# Usage: build-image.sh SHA OUT.tar   (prints the content key)
set -eu
sha=$1 out=$2
here=$(cd "$(dirname "$0")" && pwd)
stage=$(mktemp -d)
cp -R "$here/rootfs/." "$stage/"
mkdir -p "$stage/etc/ruff-ci" && printf '%s\n' "$sha" > "$stage/etc/ruff-ci/sha"
tar --uid 0 --gid 0 -C "$stage" -cf "$stage.tar" .
crane mutate public.ecr.aws/docker/library/ubuntu:24.04@sha256:a61567bd31828687156d735ea8eb01ba4e37636e225dd6a48ba94136a70d9d61 \
  --platform linux/amd64 --append "$stage.tar" --entrypoint /usr/local/bin/boot --user 0 --workdir /workspace/ruff \
  -e HOME=/home/ubuntu -e CARGO_HOME=/home/ubuntu/.cargo -e RUSTUP_HOME=/home/ubuntu/.rustup \
  -e PATH=/home/ubuntu/.cargo/bin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
  -e UV_LOCKED=1 -e UV_CACHE_DIR=/home/ubuntu/.cache/uv -e UV_PYTHON_INSTALL_DIR=/home/ubuntu/.local/share/uv/python \
  -e CARGO_INCREMENTAL=0 -e CARGO_NET_RETRY=10 -e CARGO_PROFILE_DEV_LTO=false -e CARGO_PROFILE_DEV_OPT_LEVEL=0 \
  -e CARGO_PROFILE_DEV_DEBUG=line-tables-only -e CARGO_TERM_COLOR=never \
  -e CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER=clang \
  -e "CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_RUSTFLAGS=-C link-arg=-fuse-ld=/usr/local/bin/mold" \
  -e HAWK_VERSION=0.1.15 -e PYTHON_VERSION=3.14 -e NEXTEST_PROFILE=ci -e MDTEST_EXTERNAL=1 \
  -t ruff-ci:bootstrap -o "$out" >/dev/null
rm -rf "$stage" "$stage.tar"
cat "$here"/rootfs/usr/local/bin/* "$here/build-image.sh" | { cat; printf '%s' "$sha"; } | shasum -a 256 | cut -c1-32
