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

sub xml_escape {
    my $string = shift;
    $string =~ s/([^-\n\t !\#\$\%\(\)\*\+,\.\~\/\:\;=\?\@\[\\\]\^_\`\{\|\}abcdefghijk
lmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789])/'&#'.(ord($1)).';'/eg;
    return $string;
}

sub _xml {
    my $self = shift;
    my $transform = shift;
    my @xml;
    for my $header (keys %{$transform->{headers}}) {
        push @xml, map {'<field name="header_' . xml_escape($header) . '">' . xml_escape($_) . "</field>\n"} @{$transform->{headers}{$header}};
    }

    for my $metadata (keys %{$transform->{metadata}}) {
        my $value = $transform->{metadata}{$metadata};
        push @xml, map {'<field name="metadata_' . xml_escape($metadata) . '">' . xml_escape($_) . "</field>\n"} ref($value) eq 'ARRAY' ? @{$value} : $value;
    }

    push @xml, '<field name="content">' . xml_escape($transform->{content}) . '</field>';
    push @xml, '<field name="id">' . xml_escape($transform->{id}) . '</field>';
    return '<doc>' . join('', @xml) . '</doc>';
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