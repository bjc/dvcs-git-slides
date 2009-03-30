#!/usr/bin/env perl

=head1 NAME

read_object.pl - Read and print an object from the git object store.

=head1 SYNOPSIS

read_object.pl filename

=head1 DESCRIPTION

Reads C<filename> as a git object and print it out in a human-readable
format. The purpose of this code is to show the ease of reading and
writing git objects and explore the git object store directly.

By using a short perl program, the object store formats can be
trivially verified and understood.

=cut

use Compress::Zlib;
use Digest::SHA qw(sha1_hex);
use File::Basename;

use strict;
use warnings;

my @filedata = <>;
my ($signature, $type, $size, $data) = read_object(join('', @filedata));
my $out = format_object($type, $data);

print "signature: $signature\ntype: $type\nsize: $size\n"
    . ("-" x 40) . "\n$out\n";

=head1 FUNCTIONS

=over

=item C<read_object($str)>

Reads C<$str> as git object and returns it unpacked into a signature,
type, size, and data section.

All objects are prefixed with their type, a space, their size, and a
NUL byte before being compressed. The type and size are normal
strings, and thus there is no size limit of blobs.

Signature is computed based on the uncompressed blob, but does include
the type and size prefix.

=cut
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

=item C<format_object($str)>

Returns a readable representation of C<$str>. If no useful
representation can be created, a hexdump is returned by default.

Because commits and tags are expected to be ASCII data, just return
them without any formatting, whereas trees and blobs are turned into
appropriate representations.

=cut
sub format_object {
    my ($type, $obj) = @_;

    if ($type eq 'commit' || $type eq 'tag') {
        $obj;
    } elsif ($type eq 'tree') {
        format_tree($obj)
    } elsif ($type eq 'blob') {
        hexdump($obj);
    } else {
        warn "Unknown object type, showing hex representation: $type.\n";
        hexdump($obj);
    }
}

=item C<format_tree($str)>

Reads C<$str> as a tree object as `$filemodes $name\0$id', where $id
is a binary SHA-1 ID. Returns the tree as rows of `$filemode
$id\t$name', as git-ls-tree(1).

Interestingly, tree objects use a binary ID instead of an ASCII
string, and this appears to be the only place where that's done.

=cut
sub format_tree {
    my ($str) = @_;

    my @tree = split /\0(.{20})/, $str;
    my @rc = ();
    while (@tree) {
        my ($info, $id) = (shift @tree, shift @tree);
        unless ($id || @tree) {
            $id = substr($info, -20);
            $info = substr($info, 0, -21);
        }
        $info =~ /^([^ ]*) (.*)/;
        my ($mode, $name) = ($1, $2);
        my @bytes = unpack('C*', $id);
        my $sig = join '', map { sprintf('%02x', $_) } @bytes;

        push @rc, "$mode $sig\t$name";
    }
    join "\n", @rc;
}

=item C<hexdump($str)>

Returns C<$str> as rows of 16 hexadecimal numbers, followed by their
character representations, if printable, otherwise `.'

=cut
sub hexdump {
    my ($str) = @_;

    my ($i, $len, @chunks) = (0, length($str), ());
    while ($i < $len) {
        my $rem = $len - $i;
        $rem = 16 unless $rem < 16;
        push @chunks, substr($str, $i, $rem);
        $i += $rem;
    }

    join "\n", map {
        my @chars = unpack('C*', $_);
        my @hex = map { sprintf('%02x ', $_) } @chars;
        my @filtered = map { ($_ >= 040 && $_ <= 0176) ? pack('C', $_) : '.' } @chars;
        my $spaces = (16 - @hex) * 3 + 4;
        join('', @hex) . (' ' x $spaces) . join('', @filtered)
    } @chunks;
}

=back

=head1 AVAILABILITY

L<http://github.com/bjc/dvcs-git-slides>

=head1 AUTHOR

Brian Cully <bjc@kublai.com>

=cut

1;
