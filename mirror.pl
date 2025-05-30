#!/usr/bin/perl

use feature 'unicode_strings';
use feature 'say';
use strict;
binmode STDOUT, ":utf8";

use FileHandle;
use HTML::LinkExtor;
use LWP::RobotUA;
use WWW::RobotRules;
use URI;

my $start_url = qw{ https://komascript.de/ };

my $pattern = '';
my $host = URI->new(URI->new($start_url)->canonical)->host;

my %url_seen;
my @links;

my $uas = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';
my $ua = LWP::RobotUA->new($uas, 'mirror@live.de');
$ua->delay(0); # in Minuten
$ua->rules(WWW::RobotRules->new($uas)); # robots.txt-Objekt
$ua->ssl_opts(  # we don't verify hostnames of TLS URLs
		verify_mode   => 'SSL_VERIFY_PEER',
		verify_hostname => 0, 
);

my $more;
my %urls;
my $count = 0;

$urls{$start_url}++;
do {
	
	$more = scalar keys %urls;
	
	foreach my $url (keys %urls) {
		
		
		$url =~ s/\#.*//; # remove hash part
		next if exists $url_seen{$url};
		$url_seen{$url}++;
		next if index(lc $url,'http') != 0;
		next if $host ne URI->new(URI->new($url)->canonical)->host;
		next if length $pattern > 0 && index($url,$pattern) < 0;
		push(@links, ($url));
		
		say ++$count . "/$more $url";
		
		my $r = $ua->request(HTTP::Request->new( GET => $url ));
		#say $r->content;
		if ($r->header('content-type') =~ /(html|xml)/i) {
			
			my $p = HTML::LinkExtor->new(\&get_links,$r->base);
			$p->parse($r->content);		
		}
		
	}
	
} while( scalar keys %urls > $more );

my $log = FileHandle->new(">mirror_$host.log");
if (defined $log) {
	print $log join("\n",@links);
	undef $log;
}

say "$#links links found";

# Callback für das Extrahieren der Links
sub get_links {
	my($tag, %attr) = @_;
	return if $tag ne 'a' && $tag ne 'area' && $tag ne 'frame' && $tag ne 'iframe';
	grep {$urls{$_}++} values %attr;
}