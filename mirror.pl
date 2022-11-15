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

my $start_url = qw{ http://www.vaterabraham.de/bio/bio_n.html };
my $pattern = '';
my $host = URI->new(URI->new($start_url)->canonical)->host;

my %url_seen;
my @links;

my $uas = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/104.0.0.0 Safari/537.36';
my $ua = LWP::RobotUA->new($uas, 'mirror@live.de');
$ua->delay(0); # in Minuten
$ua->rules(WWW::RobotRules->new($uas)); # robots.txt-Objekt

my $more;
my %urls;
$urls{$start_url}++;
do {
	
	$more = scalar keys %urls;
	
	foreach my $url (keys %urls) {
		
		next if exists $url_seen{$url};
		$url_seen{$url}++;
		next if index(lc $url,'http') != 0;
		next if $host ne URI->new(URI->new($url)->canonical)->host;
		next if length $pattern > 0 && index($url,$pattern) < 0;
		push(@links, ($url));
		
		my $r = $ua->request(HTTP::Request->new( GET => $url ));
		
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