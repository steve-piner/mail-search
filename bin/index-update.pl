#!/usr/bin/env perl
use 5.014;
use strict;
use warnings;
use autodie;

use version; our $VERSION = qv('0.0.1');

use File::Basename qw[dirname];
use Cwd qw[realpath];
BEGIN {
    require lib;
    lib->import(realpath dirname($0) . '/../lib');
}

use MailSearch::Config;
use MailSearch::Index;

my $config = MailSearch::Config->new(config => realpath dirname($0) . '/../etc/mail-search.ini');
my $ms = MailSearch::Index->new(config => $config);
$ms->run();
