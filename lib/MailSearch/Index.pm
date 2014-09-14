package MailSearch::Index;
use 5.014;
use strict;
use warnings;
use autodie;

use version; our $VERSION = qv('0.0.1');

use namespace::autoclean;
use Moose;

use MailSearch::Util 'require_object';

has _fetch => (
    is => 'rw',
);

has _transform => (
    is => 'rw',
);

has _load => (
    is => 'rw',
);

sub BUILD {
    my $self = shift;
    my $args = shift;

    my $config = $args->{config}->section(__PACKAGE__);
    $self->_fetch(require_object($config->{fetch}, config => $args->{config}));
    $self->_transform(require_object($config->{transform}, config => $args->{config}));
    $self->_load(require_object($config->{load}, config => $args->{config}));
}

sub run {
    my $self = shift;

    for ($self->_fetch, $self->_transform, $self->_load) {
        $_->start();
    }

    while (my $message = $self->_fetch->fetch) {
        my $transform = $self->_transform->transform($message);
        $self->_load->load($transform);
    }

    for ($self->_fetch, $self->_transform, $self->_load) {
        $_->finish();
    }
}

__PACKAGE__->meta->make_immutable;
