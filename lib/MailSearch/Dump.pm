package MailSearch::Dump;
use 5.014;
use strict;
use warnings;
use autodie;

use version; our $VERSION = qv('0.0.1');

use namespace::autoclean;
use Moose;
use Data::Printer;

with 'MailSearch::Roles::Load';

sub load {
    my $self = shift;
    my $transform = shift;
    p $transform;
    return;
}

sub start {
    return;
}

sub finish {
    return;
}

__PACKAGE__->meta->make_immutable;
