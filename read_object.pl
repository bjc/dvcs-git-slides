#!/usr/bin/env perl

use Compress::Zlib;
use Digest::SHA qw(sha1_hex);
use File::Basename;
use Data::Dumper;

use strict;
use warnings;

my @filedata = <>;
my ($signature, $type, $size, $data) = read_object(join('', @filedata));
my $out = format_object($type, $data);

print "signature: $signature\ntype: $type\nsize: $size\n"
    . ("-" x 40) . "\n$out\n";

sub read_object {
    my ($zlib_data) = @_;

    my $raw_data = uncompress($zlib_data)
        || die "Couldn't uncompress zlib data.";
    my $sig = sha1_hex($raw_data);
    $raw_data =~ /(.*?) (.*?)\0(.*)/s || die "Invalid object format.";

    my ($type, $size, $data) = ($1, $2, $3);
    warn "Size mismatch: got $size, but was actually " . length($data)
        unless length($data) == $size;

    ($sig, $type, $size, $data);
}

sub format_object {
    my ($type, $obj) = @_;

    if ($type eq 'commit') {
        $obj;
    } elsif ($type eq 'tag') {
        warn 'TODO - unimplemented';
        join '', map { sprintf('%02x ', $_) } unpack('C*', $obj);
    } elsif ($type eq 'tree') {
        warn 'TODO - unimplemented';
        join '', map { sprintf('%02x ', $_) } unpack('C*', $obj);
    } elsif ($type eq 'blob') {
        warn 'TODO - unimplemented';
        join '', map { sprintf('%02x ', $_) } unpack('C*', $obj);
    } else {
        warn "Unknown object type, showing hex representation: $type.\n";
        join '', map { sprintf('%02x', $_) } unpack('C*', $obj);
    }
}

1;
