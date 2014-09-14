package MailSearch::Config;
use 5.014;
use strict;
use warnings;
use autodie;

use version; our $VERSION = qv('0.0.1');

use namespace::autoclean;
use Moose;

use Config::Tiny;

has file => (
    is => 'ro',
    required => 1,
    init_arg => 'config',
);

has _config => (
    is => 'ro',
    lazy => 1,
    required => 1,
    builder => '_load_config',
);

sub _load_config {
    my $self = shift;
    my $config = Config::Tiny->read($self->file, 'utf8')
        or die "Can't read config file '" . $self->file . "'";
    return $config;
}

sub section {
    my $self = shift;
    my $section = shift;
    return $self->_config->{$section};
}

sub must_have {
    my $self = shift;
    my $section = shift;
    my @missing = grep {not exists $self->_config->{$section}{$_}} @_;
    if (@missing) {
        die "Missing config parameters for section '$section': '"
            . join("', '", @missing) . "'";
    }
}
__PACKAGE__->meta->make_immutable;
