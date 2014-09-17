package MailSearch::Roles::Fetch;
use 5.014;
use strict;
use warnings;
use autodie;

use version; our $VERSION = qv('0.0.1');

use namespace::autoclean;
use Moose::Role;

requires qw(fetch start finish);

1;
