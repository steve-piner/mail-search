package MailSearch::Util;
use 5.014;
use strict;
use warnings;
use autodie;

use version; our $VERSION = qv('0.0.1');

use Carp 'croak';
use Exporter 'import';
our @EXPORT_OK = qw[
    require_object
    slow_connect
];

sub require_object {
    my $class = shift;
    $class =~ m/\w+ (?: :: \w+)/x or croak "Invalid module name '$class'";
    eval "require $class";
    die $@ if $@;
    return $class->new(@_);
}

use IO::Socket;

sub slow_connect {
    my ($address, $seconds, $progress) = @_;

    my $socket = IO::Socket::INET->new($address);
    while (not defined $socket and $seconds > 0) {
        sleep 1;
        $seconds--;
        print '.' if $progress;
        $socket = IO::Socket::INET->new($address);
    }
    if (not defined $socket) {
        croak "Could not connect to $address";
    }
    return $socket;
}

1;

