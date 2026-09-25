#!/bin/bash
# Smoke test for minimal-perl (prod).
set -eu
: "${IMAGE:?IMAGE env var required}"

echo "Testing perl version..."
ver=$(docker run --rm "$IMAGE" -v 2>&1)
echo "$ver" | grep -qE 'This is perl 5, version [0-9]+' \
  || { echo "FAIL: version string not found: $ver"; exit 1; }

echo "Testing perl -V configuration dump..."
cfg=$(docker run --rm "$IMAGE" -V 2>&1)
echo "$cfg" | grep -q 'osname=linux' \
  || { echo "FAIL: perl -V did not report a linux build"; exit 1; }

echo "Testing core modules load (offline)..."
# Exercises the stdlib that actually needs the shared libs we ship: Compress::Zlib
# (zlib), Digest::SHA (XS), Encode (XS), POSIX (libc), JSON::PP (pure perl).
mods=$(docker run --rm "$IMAGE" -e '
  use strict; use warnings;
  use Data::Dumper; use JSON::PP; use Encode; use MIME::Base64;
  use Digest::SHA; use Compress::Zlib; use POSIX; use File::Temp;
  print "modules-ok\n";' 2>&1)
echo "$mods" | grep -q 'modules-ok' \
  || { echo "FAIL: core module load failed: $mods"; exit 1; }

echo "Testing a real round-trip: JSON encode/decode + SHA + gzip (offline)..."
out=$(docker run --rm "$IMAGE" -e '
  use strict; use warnings;
  use JSON::PP; use Digest::SHA qw(sha256_hex); use Compress::Zlib;
  my $data = { image => "minimal-perl", n => 42, list => [1,2,3] };
  my $json = JSON::PP->new->canonical->encode($data);
  my $back = JSON::PP->new->decode($json);
  die "json round-trip failed" unless $back->{n} == 42 && $back->{list}[2] == 3;
  my $gz  = Compress::Zlib::memGzip($json) or die "gzip failed";
  my $un  = Compress::Zlib::memGunzip($gz) or die "gunzip failed";
  die "gzip round-trip failed" unless $un eq $json;
  printf "roundtrip-ok sha=%s\n", substr(sha256_hex($json), 0, 12);' 2>&1)
echo "$out" | grep -q 'roundtrip-ok' \
  || { echo "FAIL: round-trip failed: $out"; exit 1; }
echo "$out"

echo "Testing regex + unicode handling (offline)..."
uni=$(docker run --rm "$IMAGE" -e '
  use strict; use warnings; use utf8; use Encode qw(encode_utf8);
  my $s = "héllo wörld";
  die "regex failed" unless $s =~ /w(ö)rld/;
  die "capture failed" unless $1 eq "ö";
  print "unicode-ok len=", length(encode_utf8($s)), "\n";' 2>&1)
echo "$uni" | grep -q 'unicode-ok' \
  || { echo "FAIL: unicode handling failed: $uni"; exit 1; }

echo "Testing the workdir is writable by nonroot..."
work=$(mktemp -d); chmod 0777 "$work"
trap 'rm -rf "$work"' EXIT
docker run --rm -v "$work:/app" "$IMAGE" -e '
  open(my $fh, ">", "/app/out.txt") or die "open: $!";
  print $fh "written\n"; close $fh;' 2>&1
[ -s "$work/out.txt" ] || { echo "FAIL: perl could not write to /app"; exit 1; }

echo "Verifying non-root..."
uid=$(docker inspect --format '{{.Config.User}}' "$IMAGE")
[ "$uid" = "65532" ] || { echo "FAIL: expected uid 65532, got '$uid'"; exit 1; }

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo x" 2>/dev/null \
  && { echo "FAIL: shell found!"; exit 1; } \
  || echo "No shell (as expected)"

echo "All perl tests passed!"
