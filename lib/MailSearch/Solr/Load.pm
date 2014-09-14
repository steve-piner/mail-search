package MailSearch::Solr::Load;
use 5.014;
use strict;
use warnings;
use autodie;

use version; our $VERSION = qv('0.0.1');

use namespace::autoclean;
use Moose;
use HTTP::Tiny;
use Carp 'croak';

sub BUILD {
    my ($self, $args) = @_;
    croak "Parameter 'config' is required" unless exists $args->{config};
    $args->{config}->must_have(__PACKAGE__, 'solr address', 'base url');
    $self->_config($args->{config}->section(__PACKAGE__));
}

has _config => (
    is => 'rw',
);

has _http => (
    is => 'ro',
    lazy => 1,
    required => 1,
    default => sub { HTTP::Tiny->new() },
);

sub _solr_url {
    my $self = shift;
    return 'http://' . $self->_config->{'solr address'}
        . $self->_config->{'base url'} . '/update';
}

sub load {
    my $self = shift;
    my $transform = $self->_xml(shift);

    $self->_http->post($self->_solr_url, {
        'headers' => {
            'Content-Type' => 'text/xml',
        },
        content => '<add>' . $transform . '</add>',
    });

    return;
}

sub _xml {
    my $self = shift;
    my $transform = shift;
    my $xml;
   
}

sub start {
    return;
}

sub finish {
    my $self = shift;

    $self->_http->post($self->_solr_url, {
        'headers' => {
            'Content-Type' => 'text/xml',
        },
        content => '<commit/>',
    });

    return;
}

__PACKAGE__->meta->make_immutable;