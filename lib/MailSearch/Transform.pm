package MailSearch::Transform;
use 5.014;
use strict;
use warnings;
use autodie;

use version; our $VERSION = qv('0.0.1');

use namespace::autoclean;
use Moose;

use Email::MIME;
use MailSearch::Tika;

has _config => (
    is => 'ro',
    required => 1,
    init_arg => 'config',
);

has _tika => (
    is => 'ro',
    lazy => 1,
    required => 1,
    default => sub { MailSearch::Tika->new(config => $_[0]->_config) },
);

sub transform {
    my $self = shift;
    my $message = shift;
    my $email = Email::MIME->new($message->{message});
    my $transform = $self->_tika->extract($message->{message});
    for ($email->header_names) {
        $transform->{headers}{$_} = [$email->header($_)];
    }
    $transform->{id} = $message->{id};

    return $transform;
}

sub start {
    my $self = shift;
    $self->_tika->start;
}

sub finish {
    my $self = shift;
    $self->_tika->finish;
}

__PACKAGE__->meta->make_immutable;
