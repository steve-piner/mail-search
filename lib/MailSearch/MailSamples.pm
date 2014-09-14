package MailSearch::MailSamples;
use 5.014;
use strict;
use warnings;
use autodie;

use version; our $VERSION = qv('0.0.1');

use namespace::autoclean;
use Moose;

has config => (
    is => 'ro',
    required => 1,
);

has _files => (
    is => 'rw',
    lazy => 1,
    required => 1,
    builder => '_list_files',
);

sub _list_files {
    my $self = shift;
    return [grep{ -f } glob($self->config->section(__PACKAGE__)->{files})];
}

sub fetch {
    my $self = shift;
    return unless @{$self->_files};
        
    open my $file, '<', shift @{$self->_files};
    local $/;
    my $message = <$file>;
    close $file;
    return {
        message => $message,
    };
}

sub start {
    return;
}

sub finish {
    return;
}

__PACKAGE__->meta->make_immutable;
