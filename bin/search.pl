#!/usr/bin/env perl
use Mojolicious::Lite;
use strict; # Not needed, but keeps perlcritic happy.

# Documentation browser under "/perldoc"
plugin 'PODRenderer';

get '/' => sub {
    my $c = shift;
    my $response = solr_request($c->ua, q => $c->param('q'));
    $c->stash(raw_output => $response);
    if ($response->{response}{numFound} > 0) {
        my $output = '';
        for my $results (@{$response->{response}{docs}}) {
            $c->stash({
                subject => $results->{header_Subject}[0],
                from => $results->{header_From}[0],
                to => $results->{header_To}[0],
                extract => $results->{content}[0],
            });
            $output .= $c->render_to_string('email-result');
        }
        $c->stash(results => $output);
    }
    else {
        $c->stash(results => $c->render_to_string('no-results'));
    }
    $c->render(template => 'search');
};

sub solr_request {
    my $ua = shift;
    my $url = make_solr_url(@_, wt => 'json');
    return $ua->get($url)->res->json;
}

sub make_solr_url {
    my @args = @_;
    my $url = 'http://localhost:8983/solr/mail-search/select';
    my $args = '';
    for (my $i = 0; $i < @args; $i += 2) {
        $args .= $args[$i] . '=' . $args[$i + 1] . '&';
    }
    $args = substr $args, 0, length($args) - 1;

    $url .= '?' . $args;
    return $url;
}

app->start;
__DATA__

@@ email-result.html.ep
<h3><%= $subject %></h3>
<p><b>From:</b> <%= $from %><br>
<b>To:</b> <%= $to %></p>
<p><%= $extract %></p>

@@ no-results.html.ep
<h2>No results found</h2>
<p>No results matching your query were found.</p>

@@ search.html.ep
% layout 'default';
% title 'Welcome';
%= form_for '/' => begin
    %= text_field 'q'
    %= submit_button 'Go'
% end
%== $results
<pre>
%= dumper $raw_output
</pre>

@@ layouts/default.html.ep
<!DOCTYPE html>
<html>
  <head><title><%= title %></title></head>
  <body><%= content %></body>
</html>
