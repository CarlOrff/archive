#!/usr/bin/perl
-wT;

#####a#############################################################################################
# PURPOSE: extracts metada from HTML and PDF URLs, stores them in the Internet Archive
# (https://archive.org/) and generates a report (HTML or Atom) that is suitable for posting it 
# to a blog or as Atom feed. The report can get ftp'ed.
#
# USAGE: store URLs as break-separated list in file urls.txt and start archive.pl
#    Optional arguments:
#               -a                        Atom feed instead of HTML output
#               -c <creator>              Name of the feed author (feed only)
#               -C                        Clone Wayback save URL (experimental) 
#               -d <path>                 FTP path or WordPress blog id on a multisite instance.
#               -D                        Debug mode - don't save to Internet Archive
#               -f <filename>             Other input file name than urls.txt
#               -F                        Download root URLs through Firefox (recommended)
#               -h                        show commands
#               -i <title>                Feed or HTML title
#               -k <consumer key>         *deprecated*
#               -l                        save linked documents
#               -n <username>             FTP or WordPress user
#               -o <host>                 FTP host
#               -p <password>             FTP or WordPress password
#               -P <proxy>                A proxy, fi. http://localhost:9050 for TOR service
#               -r                        Obey robots.txt
#               -s                        Save feed in Wayback machine (feed only)
#               -S                        Store Wayback form response in file (for debugging) 
#               -t <access token>         *deprecated*
#               -T <float>                Seconds delay per URL in seconds to respect IA's request limit
#               -u <URL>                  Feed or WordPress XMLRPC URL
#               -v                        Version info
#               -w                        *deprecated*
#               -W <float>                Seconds to wait after Wayback error
#               -x <secret consumer key>  *deprecated*
#               -y <secret access token>  *deprecated*
#               -z <time zone>            Time zone (WordPress only)
#
#
# LICENSE: GNU GENERAL PUBLIC LICENSE v.3
#
# PROJECT PAGE: https://ingram-braun.net/erga/archive-pl-a-perl-script-for-archiving-url-sets-in-the-internet-archive/
#
##################################################################################################

use strict;

my $start = time;

#use diagnostics;
#use warnings;
#use LWP::ConsoleLogger::Everywhere;
#require Data::Dumper;
use feature 'say';
use utf8;
binmode(STDOUT, ":utf8");

use Browser::Open qw( open_browser );
use DateTime;
use DateTime::Format::W3CDTF;
use Feed::Find;
use FileHandle;
use FindBin ();
require Firefox::Marionette;
use GD;
use Getopt::Std;
use HTML::Entities;
use HTML::LinkExtor;
use HTML::Strip;
use Image::Info qw( dim image_info html_dim );
use Image::Thumbnail;
use JSON::XS qw ( decode_json );
use List::Util qw( reduce );
require LWP::Protocol::socks; # loaded automatically but must get installed
use LWP::RobotUA;
use MIME::Base64;
use Net::FTP;
use Net::IDN::Encode 'domain_to_ascii';
use PDF::API2;
use POSIX qw(strftime);
use Scalar::Util;
use Try::Tiny;
use URI;
use URI::Encode;
use URI::URL;
use Web::Scraper;
use WP::API;
use WWW::Mechanize;
use WWW::RobotRules;
use XML::Atom::SimpleFeed;
use XML::Feed;
use XML::Twig;

if ( scalar @ARGV == 0 ) { 
	say 'Call "archive pl -h" to display options!';
    exit; } # 'die' would print the line number

##################################################################################################
# global variables
##################################################################################################


my $VERSION = "2.5";
my $botname = "archive.pl-$VERSION";
my @urls;
my $author_delimiter = '/';

# user agent string
my $atomurl = "https://ingram-braun.net/erga/archive-pl-a-perl-script-for-archiving-url-sets-in-the-internet-archive/#ib_campaign=$botname&ib_medium=atom&ib_source=outfile";
my $htmlurl = "https://ingram-braun.net/erga/archive-pl-a-perl-script-for-archiving-url-sets-in-the-internet-archive/#ib_campaign=$botname&ib_medium=html&ib_source=outfile";

my $ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36';

my $wayback_url = 'http://web.archive.org/save/';

my $download_method = 0; # 0 (GET) or 1 (POST)

# init LinkExtor
my %raw_urls;
my $p = HTML::LinkExtor->new(\&get_links);

# linked URLs that should get saved, too
my %linked;

# set up blacklist
my %blacklist;
init_blacklist();

# fetch options
my %opts;
getopts('ac:Cd:Df:Fhi:k:ln:o:p:P:rsSt:T:u:vwW:x:y:z:', \%opts);
foreach my $opt ('k','t','w','x','y') {
	say "Option -$opt is deprecated and will not take effect." if $opts{$opt};
}

my @commands = (
	'-a                        Atom feed instead of HTML output',
	'-c <creator>              Name of the feed author (feed only)',
	'-C                        Clone Wayback save URL (experimental)',
	'-d <path>                 FTP path',
	'-D                        Debug mode - don\'t save to Internet Archive',
	'-f <filename>             Other input file name than urls.txt',
	'-F                        Download root URLs through Firefox (recommended)',
	'-h                        show commands',
	'-i <title>                Feed or HTML title',
	'-k <consumer key>         *deprecated*',
	'-l                        save linked documents',
	'-n <username>             FTP or WordPress user',
	'-o <host>                 FTP host',
	'-p <password>             FTP or WordPress password',
	'-P <proxy>                A proxy server, fi. socks4://localhost:9050 for TOR service',
    '-r                        Obey robots.txt',
	'-s                        Save feed in Wayback machine',
	'-S                        Store Wayback form response in file (for debugging)',
	'-t <access token>         *deprecated*',
	"-T <float>                Seconds delay per URL in seconds to respect IA's request limit",
	'-u <URL>                  Feed or WordPress (xmlrpc.php) URL',
	'-v                        Version info',
	'-w                        *deprecated*',
	'-W <float>                Seconds to wait after Wayback error',
	'-x <secret consumer key>  *deprecated*',
	'-y <secret access token>  *deprecated*',
	'-z <time zone>            Time zone (WordPress only)',
);

# Display options and version
if ($opts{h}) {
	local $, = "\n\t";
	print "\nAVAILABLE OPTIONS:\n", @commands, "\n";
	exit;
}
elsif ($opts{v}) {
	say "This is archive.pl $VERSION by Ingram Braun";
	exit;
}

# init WWW::Mechanize
my $mech = WWW::Mechanize->new( 
	agent => $ua,
	autocheck => 1,
	#cookie_jar => undef,
	#noproxy => 0,
	protocols_allowed => [ 'http', 'https' ],
	#strict_forms => 1,
);
$mech->proxy( [ qw( http https ) ] => $opts{P} ) if ( $opts{P} && length $opts{P} > 0 );
my $mech_clone;
# EXPERIMENTAL: load Wayback URL only once:
if ( $opts{C} ) {
	
	do {
		$mech->get( $wayback_url );
		$mech_clone = $mech->clone( );
	} unless ( $mech->success( ) ); 
}
# if credentials available the -o switch indicates FTP, WP otherwise,
my $wp;
if ( $opts{o} && length $opts{f} > 0 ) { $wp = 0; }
elsif ( $opts{n} && $opts{p} ) { $wp = 1; }
else { $wp = 0; }

# save old feed
push( @urls, $opts{u} ) if length $opts{u} > 0 && $opts{s} && $opts{a} && !$wp;

my $creator = ($opts{c} && length $opts{c} > 0) ?  $opts{c} : "Ingram Braun";
my $infile = ($opts{f} && length $opts{f} > 0) ?  $opts{f} : "urls.txt";
my %atomurl = ($opts{u} && length $opts{u} > 0) ? ( 'rel' => 'self', 'href' => encode_entities($opts{u}), ) : ( 'href' => $atomurl, ) if $opts{a};

my $out_title = ($opts{i}) ? $opts{i} : "$botname result";
my $outfile = ($opts{a}) ? XML::Atom::SimpleFeed->new(
     id => $atomurl{href},
     title   =>  $out_title,
     link    => \%atomurl,
     updated => DateTime::Format::W3CDTF->new()->format_datetime(DateTime->now), 
     author  => $creator, # needed since it is not sure that all entries have an author
     generator  => $botname,
 ) : ( $wp ) ? '<ul>' : "<!doctype html>\n<head>\n<meta http-equiv='Content-Type' content='text/html; charset=UTF-8'>\n<meta name='generator' content='$botname'>\n<link rel='help' href='$htmlurl'>\n<title>$out_title</title>\n</head>\n<body>\n\n<ul>\n";


##################################################################################################
# read URL list from file (line break separated list)
##################################################################################################

my $fh = FileHandle->new($infile, "r");
binmode($fh, ":encoding(UTF-8)");
if (defined $fh) {
	
	while(<$fh>) {
		push(@urls,split(/\n+[^a-z]*/,$_));
	}
	
	# remove BOM
	$urls[0] =~ s/^\xEF\xBB\xBF//;
	$urls[0] =~ s/^\N{BOM}//;
	$urls[0] =~ s/^\N{U+FEFF}//;
	$urls[0] =~ s/^\x{FEFF}//;
	$urls[0] =~ s/^\N{ZERO WIDTH NO-BREAK SPACE}//;

	#print join( "\n", @urls ); exit;
	undef $fh;       # automatically closes the file
}
else { die "Could not open $infile"; }

##################################################################################################
# initialize robot object
##################################################################################################
my $lwp;
if ($opts{r}) {
	$lwp = LWP::RobotUA->new($ua, 'bot@example.com');
	$lwp->delay(0); # minutes (0 because we don't crawl domains recursively)
	$lwp->ssl_opts(  # we don't verify hostnames of TLS URLs
		verify_mode   => 'SSL_VERIFY_PEER',
		verify_hostname => 0, 
	);
	$lwp->rules(WWW::RobotRules->new($ua)); # obey robots.txt
}
else {
	$lwp = LWP::UserAgent->new( agent => $ua );
	$lwp->ssl_opts(  # we don't verify hostnames of TLS URLs
		verify_mode   => 'SSL_VERIFY_PEER',
		verify_hostname => 0, 
	);
}
# Save all size of twitter images

##################################################################################################
# loop through URLs
##################################################################################################

my $count = 0;
my %urls_seen;

foreach my $url ( @urls ) {

	
	# don't fetch empty URLs
	next if length $url < 1 || exists( $urls_seen{ $url } ); # avoid empty lines or duplicate URLs
	
	my $parsed_url = new URI $url;
	my $host = $parsed_url->host;
	my $scheme = $parsed_url->scheme;
	next if $scheme !~ /^https?$/;  # IA doen't save non-HTTP schemes
	my $port = $parsed_url->port;
	$host .= ':'.$port if defined $port && ( $port != 80 && $port != 443 );
	my $path = $parsed_url->path;
	my $query = $parsed_url->query;
	my $path_query = $path;
	$path_query .= '?'.$query if length $query > 0;
	my $hash = $parsed_url->fragment;	
	
	# remove hash part:
    $url = $scheme.'://'.$host.$path_query;
	next if exists( $urls_seen{ $url } ); # avoid duplicate URLs
	
	say $url;
    
    # remove high chars in path and query params:
    $path_query = URI::Encode::->new({double_encode => 0})->encode($path_query);
    
    # convert IDN to ACE
    $host = domain_to_ascii( $host );
    
    # now use prepared URL
    $url = $scheme.'://'.$host.$path_query;
	next if exists( $urls_seen{ $url } ); # avoid duplicate URLs
	
	# HTML encode URL
	my $encoded_url = encode_entities( $url );
	
	say "Start processing task #" . ++$count . ' ' . $url;
	$urls_seen{ $url }++;    #avoid duplicate URLs	
	
	# status message
	print "\nfetching ", $url, "\n";
	
	# fetch URL

	my $r = $lwp->request(HTTP::Request->new(($opts{F}) ? 'HEAD' : 'GET' => $url ));
	
	my $success = $r->is_success;
	my $mime = $r->header('content-type');
	my $length;
	my $content;
	
	if ($opts{F}) {
		
		if (!$success) {
		
			$content = get_firefox($url);
			$mime = 'text/html';
			$success = !$r->is_success;
		}
		elsif ($mime =~ /html$/) {
			
			$content = get_firefox($url);
		}
		else {
			
			$r = $lwp->request(HTTP::Request->new( GET => $url ));
			$success = $r->is_success;
			$mime = $r->header('content-type');
			$content = $r->content;
		}
		
	}
	else {
		$content = $r->content;
	}
	
	# Calculate content length
	if (index($content, '<html><head></head><body></body></html>') == 0) {
		
		$length = 0;
	}
	elsif (defined $r->header('content-length') && $r->header('content-length') =~ /^\d+$/) {
		
		$length = $r->header('content-length');
	}
	else { 
	
		$length = length $content;
	}
	
	#say "Length $length";
    
    if ($success && $length > 0 ) {
		

		print "successfull!\n";
		
		my($title, $description, $author, $language);
        	
##################################################################################################
# HTML
##################################################################################################

		if ($mime =~ /(ht|x)ml/i) {
			
			$download_method = 1;
			
			if ($opts{l}) {
			
				# link base
				my $base = $r->base;
				
				# extract links
				$p->parse($content);
				
				# expand raw urls
				my @links = map {$_ = url($_, $base)->abs;} keys %raw_urls;
				# empty buffer
				%raw_urls = ();
				
				# remove hashes
				grep { $_ =~ s/\#.*// } @links;
				
				grep { $linked{$_}++ } @links;
				
				
				# Find all feeds on a given page and extract their entry URLs.
				if ( $content =~ /(atom|rss)\+xml/i ) {

					# Alas this method only takes URLs.
					my @feeds = Feed::Find->find_in_html( \$content, $url );
					push( @links, @feeds );
					
					foreach my $feed_url ( @feeds ) {
						
						local $@;
						
						eval {

							say "FEED $feed_url";
							my $feed = XML::Feed->parse(URI->new( $feed_url ));
							
							for my $entry ( $feed->entries ) {
								push( @links, $entry->link );
							}
						}
					}
				}
				
				say 'found ' . ++$#links . ' links';
			}
		
			# Properties as lower case since Web::Scraper's contains()-method is case sensitive.
			utf8::decode($content);
			$content =~ s/(abstract|author|contributor|creator|decription|language|title)\s*(["'])/lc($1)$2/gi;
			$content =~ s/(["'])\s*(dc|dcterms|og|twitter)[:\.]([a-z])/$1lc($2):$3/gi;
        
			my $scraper = scraper {
				# title
				process_first '//meta[contains(@property,"og:title")]', "open_graph_title" => '@content';
				process_first '//meta[contains(@name,"dc:title")]', "dublin_core_title2" => '@content';
				process_first '//meta[contains(@name,"twitter:title")]', "twitter_title" => '@content';
				process_first '//h3[contains(@class,"post-title entry-title")]', "blogspot_title" => "TEXT"; # Google Blogger
				process_first "title", "title" => "TEXT";
				process_first "h1", "h1" => "TEXT";
				process '//*[starts-with(@itemprop,"headlinie")]', "schema_title" => '@content';
				# description
				process_first '//meta[contains(@property,"og:description")]', "open_graph_description" => '@content';
				process_first '//meta[contains(@name,"dc:description")]', "dublin_core_description2" => '@content';
				process_first '//meta[contains(@name,"dcterms:abstract")]', "dublin_core_abstract2" => '@content';
				process_first '//meta[contains(@name,"twitter:description")]', "twitter_description" => '@content';
				process_first '//meta[starts-with(@name,"description")]', "meta_description" => '@content';
				# scrap authors
				# we only look for Dublin Core and XML elements since Open Graph stores an URL, Twitter an account and Schema.Org needs enhanced parsing
				process '//meta[contains(@name,"dc:creator")]', "dublin_core_author2[]" => '@content';
				process '//meta[contains(@name,"dc:author")]', "dublin_core_author2[]" => '@content';
				process '//meta[contains(@name,"dc:contributor")]', "dublin_core_author2[]" => '@content';
				process '//meta[starts-with(@name,"creator")]', "meta_author[]" => '@content';
				process '//meta[starts-with(@name,"author")]', "meta_author[]" => '@content';
				process "author", "xml_author[]" => "TEXT";
				process "creator", "xml_author[]" => "TEXT";
				# look for lang attribute in root element
				process_first 'html', "html_lang" => '@lang';
				process_first 'title', "title_lang" => '@lang';
				process_first 'title', "body_lang" => '@lang';
				process_first '//meta[contains(@http-equiv,"-language")]', "meta_lang" => '@content';
				process_first '//meta[contains(@http-equiv,"-Language")]', "meta_lang2" => '@content';
			};
			my $scraper = $scraper->scrape($content);
			#print Dumper($scraper);
			
			# we assume that social media titles are better than HTML titles
			print "TITLE ";
			if (check_scraped($scraper, 'open_graph_title')) {
				$title = $scraper->{'open_graph_title'};
			}
			elsif (check_scraped($scraper, 'twitter_title')) {
				$title = $scraper->{'twitter_title'};
			}
			elsif (check_scraped($scraper, 'dublin_core_title')) {
				$title = $scraper->{'dublin_core_title'};
			}
			elsif (check_scraped($scraper, 'dublin_core_title2')) {
				$title = $scraper->{'dublin_core_title2'};
			}
			elsif (check_scraped($scraper, 'blogspot_title')) {
				$title = $scraper->{'blogspot_title'};
			}
			elsif (check_scraped($scraper, 'h1')) {
				$title = $scraper->{'h1'};
			}
			elsif (check_scraped($scraper, 'schema_title')) {
				$title = $scraper->{'schema_title'};
			}
			# the title element sometimes holds the site name
			elsif (check_scraped($scraper, 'title')) {
				$title = $scraper->{'title'};
			}
			else {
				$title = $url;
			}
			$title = trim($title);
			print length($title), " characters: \"$title\"\n";
			
			# we assume that the longest description is the best
			print "DESCRIPTION ";
			$description = reduce { length $a > length $b ? $a : $b } map {$_ if defined $_} ($scraper->{'open_graph_description'},$scraper->{'dublin_core_description'},$scraper->{'dublin_core_description2'},$scraper->{'twitter_description'},$scraper->{'dublin_core_abstract'},$scraper->{'dublin_core_abstract2'},$scraper->{'meta_description'},$scraper->{'meta_description2'});
			$description = trim($description);
			print length($description), " characters: \"$description\"\n";
			
			# join authors
			print "AUTHOR(S) ";
			if (check_scraped($scraper, 'dublin_core_author')) {
				$author = join($author_delimiter,@{$scraper->{'dublin_core_author'}});
			}
			if (check_scraped($scraper, 'dublin_core_author2')) {
				$author = join($author_delimiter,@{$scraper->{'dublin_core_author2'}});
			}
			elsif (check_scraped($scraper, 'meta_author')) {
				$author = join($author_delimiter,@{$scraper->{'meta_author'}});
			}
			elsif (check_scraped($scraper, 'xml_author')) {
				$author = join($author_delimiter,@{$scraper->{'xml_author'}}),
			}
			else {
				$author = '';
			}
			$author = trim($author);
			print length($author), " characters: \"$author\"\n";
			
			# record language
			print "LANGUAGE ";
			if (check_scraped($scraper, 'html_lang')) {
				$language = $scraper->{'html_lang'};
			}
			elsif (check_scraped($scraper, 'title_lang')) {
				$language = $scraper->{'title_lang'};
			}
			elsif (check_scraped($scraper, 'body_lang')) {
				$language = $scraper->{'body_lang'};
			}
			elsif (check_scraped($scraper, 'meta_lang')) {
				$language = $scraper->{'meta_lang'};
			}
			elsif (check_scraped($scraper, 'meta_lang2')) {
				$language = $scraper->{'meta_lang2'};
			}
			else {
				$language = '';
			}
			$language = trim($language);
			print length($language), " characters: \"$language\"\n";
			
			#add to list
            if ($opts{a}) {
                $outfile->add_entry(
                    author => encode($author),
                    link => $encoded_url,
                    summary => encode($description),
                    title => encode($title),
                );
            }
            else {
                $outfile .= '<li' . (length($language) > 1 ? ' lang="'.$language.'"' : '') . '>' . (length($author) > 1 ? encode($author).' ' : '') . '<a ' . (length($language) > 1 ? 'hreflang="'.$language.'" ' : '') . 'href="' . $encoded_url . '">' . HTML_format_title($title) . '</a>' . HTML_format_description($description) . "</li>\n";
            }
			
		}
		
##################################################################################################
# PDF
##################################################################################################

		elsif ($r->header('content-type') =~ /pdf$/i) {
			
			my ( $pdf, %infohash, $xmp );
			eval '$pdf = PDF::API2->open_scalar( $content );%infohash = $pdf->info( );$xmp = $pdf->xmpMetadata( )';
			
			if ( $a || ( !%infohash && !defined $xmp ) ) { # creating PDF object has failed
			
				utf8::decode($content);
				
				$content =~ s/\n//g;

				# PDF metadata are stored in plain text or XML, so we can process them by common string operations.
				
				# Find title
				print "title ";
				# try PDF core
				if ($content =~ /\/Title\s*?\((.*?)\)/ && length $1 > 0) {
					$title = $1;
				}
				# try Dublin Core as attribute
				elsif ($content =~ /\bdc\:title\s?=\s?("(.+?)"|'(.+?)')/i && length $+ > 0) {
					$title = $+;
				}
				# try Dublin Core as tag
				elsif ($content =~ /<dc\:title>\s*(.*?)\s*<\/dc\:title>/i && length $1 > 0) {
					$title = $1;
					$title =~ s/\s*<\/?[a-z].*?>\s*//g;
				}
				else {
					$title = $url;
				}
				print length($title), " characters\n";
				
				# Find description
				print "description ";
				# try Dublin Core
				if ($content =~ /\bdc\:description\s?=\s?("(.+?)"|'(.+?)')/i && length $+ > 0) {
					$description = $+;
				}
				else {
					$description = '';
				}
				print length($description), " characters\n";
				
				# Find author
				print "authors ";
				my %authors;
				
				# try PDF core
				if ($content =~ /\/Author\s*\((.*?)\)/ && length $+ > 0) {
					$authors{$1}++;
				}
				# try XAP
				if (scalar keys %authors == 0) {
					while ($content =~ /\bxap\:Author\s?=\s?("(.+?)"|'(.+?)')/gi && length $+ > 0) {
						my $hit = $+;
						chop($hit);
						$hit =~ s/^.+?["']//;
						last if exists($authors{$hit}); # avoid infinite loop
						$authors{$hit}++;
					}
				}
				# try Dublin Core as attribute
				if (scalar keys %authors == 0) {
					while ($content =~ /\bdc\:c(rea|ontribu)tor\s?=\s?("(.+?)"|'(.+?)')/gi && length $+ > 0) {
						my $hit = $+;
						chop($hit);
						$hit =~ s/^.+?["']//;
						last if exists($authors{$hit}); # avoid infinite loop
						$authors{$hit}++;
					}
				}
				# try Dublin Core as tag
				if (scalar keys %authors == 0) {
					while ($content =~ /<dc\:c(rea|ontribu)tor>\s*(.*?)\s*<\/dc\:c(rea|ontribu)tor>/gi && length $2 > 0) {
						my $hit = $2;
						$hit =~ s/\s*<\/?[a-z].*?>\s*//g;
						last if exists($authors{$hit}); # avoid infinite loop
						$authors{$hit}++;
					}
				}
				# try PDF/X
				if (scalar keys %authors == 0) {
					while ($content =~ /<pdfx\:myAuthorName>(.+?)<\/pdfx\:myAuthorName>/gi && length $+ > 0) {
						my $hit = $+;
						$hit =~ s/<.?pdfx\:myAuthorName>//i;
						last if exists($authors{$hit}); # avoid infinite loop
						$authors{$hit}++;
					}
				}
				if (scalar keys %authors > 0) {
					$author = join($author_delimiter,keys %authors);
				}
				else {
					$author = '';
				}
				print length $author, " characters $author\n";
			}
			else { # creating PDF object was successfull

				my $twig;
				# try to read XMP data
				eval {
					$twig = XML::Twig->new( 'index' => {
						'title' => 'dc:title/rdf:Alt/rdf:li[@xml:lang="x-default"]',
						'creator' => 'dc:creator',
						'description' => 'dc:description/rdf:Alt/rdf:li[@xml:lang="x-default"]',
						'language' => 'dc:language'
					} )->parse( $xmp );
				};
				eval '$language = $twig->index( "language" )->[0]->text';
				eval '$title = $twig->index( "title" )->[0]->text';
				eval '$author = $twig->index( "creator" )->[0]->text';
				eval '$description = $twig->index( "description" )->[0]->text';

				# try PDF core
				print "TITLE ";
				if ( !defined $title && exists($infohash{'Title'}) && length $infohash{'Title'} > 0 ) {
					$title = $infohash{'Title'};
				}
				else {
					$title = $url;
				}
				$title = trim($title);
				print length($title), " characters \"$title\"\n";
				
				# Find description
				print "DESCRIPTION ";
				# try Dublin Core
				if ( !defined $description && exists($infohash{'Subject'}) && length $infohash{'Subject'} > 0) {
					$description = $infohash{'Subject'};
				}
				else { $description = ''; }
				$description = trim($description);
				print length($description), " characters \"$description\"\n";
				
				# Find author
				print "AUTHOR(S) ";
				my %authors;
				
				# try PDF core
				if ( !defined $author && exists($infohash{'Author'}) && length $infohash{'Author'} > 0 ) {
					$authors{$infohash{'Author'}}++;
				}
				if (scalar keys %authors > 0) {
					$author = join($author_delimiter,keys %authors);
				}
				
				$author = trim($author);
				print length $author, " characters \"$author\"\n";
			}
				
			#add to HTML list
			print "print Entry\n";
			if ($opts{a}) {
				$outfile->add_entry(
					author => encode($author),
					link => $encoded_url,
					summary => encode($description),
					title => encode($title . ' [PDF]'),
				);
			}
			else {
				$outfile .= '<li>PDF: ' . (length $author > 0 ? encode($author).' ' : '') . '<a href="' . $encoded_url . '" type="application/pdf">' . HTML_format_title($title) . '</a> ' . HTML_format_description($description) . "</li>\n";
			}
		}
		
##################################################################################################
# Images
##################################################################################################
		elsif ($r->header('content-type') =~ /image/) {
				
			my $origimg = image_info(\$content);
			my($width,$height) = dim($origimg);
			my $imgfile = 'thumb.png';
			my $thumb;
			
			# if image type is not known to Image::Info
			$origimg->{'file_type'} = 'type?' if exists( $origimg->{'error'} );
			
			my $gdObj = new GD::Image($content);
			
			# make thumbnail
			new Image::Thumbnail(
				size       => 120,  # length of longest side
				create     => 1,
				input      => $gdObj,
				outputpath => $imgfile,
				outputtype => 'png',
				module => 'GD',
			) if defined $gdObj;

		
			# Open thumb and encode it
			my $img = FileHandle->new($imgfile, '<:raw');
			if (defined $img) {
			
				read($img, $thumb, -s $imgfile) ;
				undef $img;
			}
			
			# Get thumb size
			my($w, $h) = html_dim( image_info(\$thumb) );
			$description = '<img ' . $w . $h . ' src="data:image/png;base64,' .  encode_base64($thumb) . '"/>' if length $thumb > 0;
		
			# Delete thumbnail
			unlink $imgfile;
			
			if ($opts{a}) {
				$outfile->add_entry(
					link => $encoded_url,
					summary => $description,
					title => encode($title),
				);
			}
			else {
				$outfile .= '<li>IMAGE (' . $origimg->{'file_type'} .$width .' × ' . $height .') <a href="' . $encoded_url . '" type="' . $r->header('content-type') . '">' . encode_entities($encoded_url) . '</a> ' . $description . "</li>\n";
			}
		}
##################################################################################################
# Other MIME types
##################################################################################################
		else {
		
			my $warning = 'Unknown MIME type ' . $encoded_url;
		
			if ($opts{a}) {
				$outfile->add_entry(link => $encoded_url, title => $warning, summary => $r->header('content-type'));
			}
			else {
				$outfile .= '<li><a href="' . $encoded_url . '">' . $warning . '</a><br>' . $r->header('content-type') . "</li>\n";
			}
		}
	}
	
	# URL not fetched
	else {
		print "failed: " . $r->title . "\n";

        my $warning = 'WARNING: cannot fetch ' . $encoded_url;
        
        if ( $opts{a} ) {
            $outfile->add_entry(link => $encoded_url, title => $warning);
        }
        else {
            $outfile .= '<li><a href="' . $encoded_url . '">' . $warning . '</a></li>'."\n";
        }
	}

##################################################################################################
# save in Wayback Machine
##################################################################################################
	say "submit to Internet Archive";
	
	### TO DO. save various URL shapes here
	my %urls;
	$urls{$url}++;
	$urls{ bare_url( $url ) }++;
	
	if ( $host ne 'web.archive.org' ) {
	
		foreach ( keys %urls ) {
		
			my $available = get_wayback_available( $_ );
			
			say "Available in Wayback Machine:";
			if ( 'HASH' eq Scalar::Util::reftype($available) ) {
				say "\tURL: " . $$available{url} if exists( $$available{url} );
				say "\tavailable: " . $$available{archived_snapshots}{closest}{available} if exists( $$available{archived_snapshots}{closest}{available} );
				say "\tstatus: " . $$available{archived_snapshots}{closest}{status} if exists( $$available{archived_snapshots}{closest}{status} );
				if (exists( $$available{archived_snapshots}{closest}{timestamp} ) ) {
					$$available{archived_snapshots}{closest}{timestamp} =~ s/^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})$/$3.$2.$1 $4:$5:$6/;
					say "\tclosest: " . $$available{archived_snapshots}{closest}{timestamp};
				}
			}
			else {
				say "\tCan't check: $available ";
			}
		
			if ( $opts{D} ) {
				say 'DEBUG mode active: not submitted to Internet Archive!';
			}
			else {
				download_wayback( $_ );
			}
		}
	}
	else {
		say "Wayback Machine doesn\'t store its own copies again.";
	}
		
	$download_method = 0;
	
	say "****************************************************************************************\n";
} # main loop

##################################################################################################
# print file
##################################################################################################

# close list
if ( !$opts{a} ) {

	$outfile .= "</ul>\n<hr><p>Generated with <a href='$htmlurl'>$botname</a></p>";

	$outfile .= "</body>" if !$wp;
}

# Post on WordPress
if ( $wp ) {

	say "Posting on WordPress!";
	
	local $@;
	
	eval {
	
		my $api = WP::API->new(
			username         => $opts{n},
			password         => $opts{p},
			proxy            => $opts{u},
			server_time_zone => ($opts{z}) ? $opts{z} : 'UTC',
			blog_id => ($opts{d}) ? $opts{d} : 1,
		);
		 
		# fix databse saving error with 8bit ASCII 
		my $post = $api->post()->create(
			post_title    => $out_title,
			#post_date_gmt => $dt,
			post_content  => encode_entities( decode_entities( $outfile ), '^\n\x20-\x25\x27-\x7e' ),
			#post_author   => 42,
		);
	
	}
}

# create file name
my $out = ($opts{a}) ? 'archive.atom' : 'ia' . time() . '.html';

# print HTML list to file	
print "\nprint file " , $out . "\n";	
$fh = FileHandle->new($out, O_WRONLY|O_CREAT|O_TRUNC);
if (defined $fh) {
    if ($opts{a}) {
        $outfile->print($fh);
        undef $fh;
    }
    else {
        print $fh $outfile;
        undef $fh;       # automatically closes the file
    }
}

print "DONE!\n";

##################################################################################################
# FTP file
##################################################################################################

# FTP if host is available
if (length $opts{o} > 0) {

    # init FTP
    my $ftp=Net::FTP->new($opts{o}, Timeout => 240, Debug => 1) or die "Can't ftp to $opts{o}: $!\n";
    
    # user login
	$ftp->login($opts{n},$opts{p}) or die "Can't login to $opts{o}: $!\n";
    
    # upload
    grep {$ftp->cwd($_)} split/[\\\/]/, $opts{d};
    $ftp->put($out, $out);
    
    # close connection
    $ftp->quit;
}

##################################################################################################
# save linked documents
##################################################################################################	
if ($opts{l}) {

	if (defined keys %linked) {
		say "\nsaving linked documents:";
		
		grep { delete( $linked{ $_ } ) if $_ !~ /^https?:\/\/\w/ } keys %linked;
		grep { delete( $linked{ $_ } ) if url_is_blacklisted( $_ ) } keys %linked;
		say 'Saving ' . scalar( values %linked ) . ' URLs';
		
		my $lrun = 0;

		foreach my $linked (keys %linked) {
			
			next if exists( $urls_seen{ $linked } );
			
			say '#' . ++$lrun . ' ' . $linked;
			
			download_wayback( $linked ) if !$opts{D};
		}
	}
	else {
		say "No links detected!";
	}
}

my $duration = time - $start;
say "Execution time: $duration s";

##################################################################################################
# Subroutines
##################################################################################################

# arg 1: URL
# returns URL stripped off unnecessary query params
sub bare_url {
	my $u = URI->new( $_[0] );
	my $_query = $u->query;
	my $_host = $u->host;

	if    ( $_host =~ /(\A|\.)theguardian\.com$/ )   { $_query =~ s/(\A|[&;])CMP=[^&]*// }            # Guardian
	elsif ( $_host =~ /(\A|\.)sciencedirect\.com$/ ) { $_query =~ s/(\A|[&;])via[=%][^&]*// }         # Elsevier
	elsif ( $_host =~ /(\A|\.)blogspot\.[a-z]{2,}/ ) { $_query =~ s/(\A|[&;])m=[^&]*//g }             # Google Blogger
	elsif ( $_host =~ /(\A|\.)lemonde\.fr$/ )        { $_query =~ s/(\A|[&;])lmd_[a-z]+=[^&]*//g }    # Le Monde
	elsif ( $_host =~ /(\A|\.)elpais\.com$/ )        { $_query =~ s/(\A|[&;])ssm=[^&]*// }            # El País
	elsif ( $_host =~ /(\A|\.)youtube(-nocookie)?\.com$/ ) { $_query =~ s/(\A|[&;])featured=[^&]*// } # Youtube
	elsif ( $_host =~ /(\A|\.)ingram-braun\.net$/ )  { $_query =~ s/(\A|[&;])ib_[a-z]+=[^&]*//g }     # me
	
	$_query =~ s/(\A|[&;])ref(errer)?=[^&]*//;
	$_query =~ s/(\A|[&;])(fb|g|tw)clid=[^&]*//g;       # FB, Google, Twitter
	$_query =~ s/(\A|[&;])sfnsn=[^&]*//;                # FB 
	$_query =~ s/(\A|[&;])(utm|pk)_[a-z]+=[^&]*//g;     # Matomo, GA
	$_query =~ s/(\A|[&;])google_editor_picks=?[^&]*//; # Google News
	$_query =~ s/(\A|[&;])gad_[a-z]+=[^&]*//g;        	# Google Ads
	$_query =~ s/(\A|[&;])spref=[^&]*//;                # Google Blogger
	$_query =~ s/(\A|[&;])wt_mc=[^&]*//;                # Mapp
	$_query =~ s/\A&//;                                 # leading ampersand

	$u->query( $_query );
	return $u->as_string;
}

# arg 1: string
# returns string stripped off HTML tags and HTML entities
sub clean_text {
	my $hs = HTML::Strip->new(
        emit_spaces => 0
    );
    return $hs->parse( $_[0] );
}

# arg 1: description string
# returns formatted description string
sub encode {
	return $_[0] if length $_[0] == 0; # is empty
    my $str = clean_text($_[0]);
	return $str;
}

# arg 1: title string
# returns formatted title string
sub HTML_format_title {
    my $str = clean_text($_[0]);
	return $str if $str =~ /^[a-z]+\:\/\//i; # is URL
	return '<cite>' . encode_entities($str) . '</cite>';
}

# arg 1: description string
# returns formatted description string
sub HTML_format_description {
	return $_[0] if length $_[0] == 0; # is empty
    my $str = clean_text($_[0]);
	return "<br />\n" . encode_entities($str);
}

# checks if a scraper result is true
sub check_scraped {
	my $scraped = shift;
	my $tag = shift;
	return exists ($scraped->{$tag}) && length $scraped->{$tag} > 0;
}

sub download_wayback
{
	my $exec_time = time;
	
	my $max_tries = 10;
	my $try = 0;
	local $@;
	
	do {
		$try++;
		
		eval {
			
			if ( $opts{C} ) { $mech = $mech_clone->clone( ); }
			else { $mech->get( $wayback_url ); }
			#say ' CONTENT: ' . $mech->text();
			
			my $sleep_default = 20;
			$sleep_default = $opts{W} if exists( $opts{T} );
			my $sleep = 0;
			my $max_runs = 3;
			my $run = 0;
			
			do {
			
				$run++;
				$sleep = $opts{T} if exists( $opts{T} ) && ( $count > 1 && scalar @urls > 1 );
				$sleep = $sleep_default if ( $run > 1 || $try > 1 ) && $sleep < $sleep_default;
				say "Sleep $sleep seconds in order not to exceed request limit.";
				select(undef, undef, undef, $sleep); # sleep() eats integers only
			
				print "run #$try." . $run;
				
				$mech->submit_form( form_name => "wwmform_save",
					fields => {
						url => $_[0],
						capture_all => 'on',
						#capture_outlinks => 'on',
						#capture_screenshot => 'on',
						#'wm-save-mywebarchive' => 'on',
					} 
				);
				
				print ' SUCCESS' if $mech->success();
				print ' HTTP ', $mech->status();
				#print ' CONTENT: ' . $mech->text();
				#print ' TEXT: ' .  $mech->content(format=>'text');
				say '';
				# content to file (think of Docker access!)
				if ( $opts{S} ) {
					my $url_in_filename = $_[0];
					$url_in_filename =~ s/^https?:\/{2}//g;
					$url_in_filename =~ s/\W+/_/g;
					$mech->save_content( $url_in_filename.'_'.$try.'_'.$run.'.html', binary => 1 );
				}		
			} while ( !$mech->success( ) && $run <= $max_runs );
		};

		print ' ', $@ if $@;
		
	} while ( $@ && $try < $max_tries);
	
	$exec_time = time - $exec_time;
	say "Saving in IA took $exec_time seconds";
}

# Downloads via Firefox must be protected against timeouts
#arg 1: URL
#returns content
sub get_firefox {
	
	my $doc;
	my $timeout = 8;
	my $alarm_str = "Firefox timeout\n";
	eval {
		local $SIG{ALRM} = sub { die $alarm_str }; # NB: \n required
		alarm $timeout;
		$doc = Firefox::Marionette->new()->go($_[0])->html();
	};
	# This call has to be outside eval(): https://www.perlmonks.org/?node_id=759131
	alarm 0;

	return $lwp->request(HTTP::Request->new( GET => $_[0] ))->content if $@;
	return $doc;
}

# LinkExtor callback
sub get_links {
	my($tag, %attr) = @_;
	return if $tag ne 'a' && $tag ne 'area' && $tag ne 'frame' && $tag ne 'iframe' && $tag ne 'track' && $tag ne 'source';
	grep {$raw_urls{$_}++} values %attr;
}

# downloads the available API of URL in arg1
# returns hashref to decoded JSON or error message
sub get_wayback_available
{

	my $av_url = new URI $_[0];
	my $av_path_query = $av_url->path;
	$av_path_query .= '?'.$av_url->query if length $av_url->query > 0;
	$av_path_query =~ s/&/%26/g;

	my $download = 'http://archive.org/wayback/available?url=' . $av_url->host . $av_path_query;
	my $json = '{}';
	
	local $@;
	my $json;
	eval {
		$mech->get( $download );
		$json = decode_json $mech->content( raw => 1 );
	};
	
	return $@ if $@;
	return $json;
}

# checks if an URL is blacklisted.
# arg 1: url

sub url_is_blacklisted {

	my $u = new URI $_[0];

	foreach my $check (sort values %blacklist) {
		
		#say Dumper($check);
		
		my $h = $$check{host};
		my $p = $$check{path};
		my $q = $$check{query};
		
		if (length $h > 0) {
			
			next if index($h, '(?') != 0 && $u->host ne $h;
			next if $u->host !~ /$h/;
		}
		#say 'host '. $h;
		
		if (length $p > 0) {
			
			next if index($p, '(?') != 0 && $u->path ne $p;
			next if $u->path !~ /$p/;
		}
		#say 'path ' . $p;
		
		if (length $q > 0) {
			
			next if index($q, '(?') != 0 && $u->query ne $q;
			next if $u->query !~ /$q/;
		}
		#say 'query ' . $q;
		
		return 1;
	}
	
	return 0;
}

# generate blacklist (mainly of URLs that need login)
sub init_blacklist {
	
	%blacklist = (
		'AddThis 1' => {
				'host'  => 'www.addthis.com',
				'path'  => '/bookmark.php',
				'query' => '',
		},
		'AddThis 2' => {
				'host'  => 'v1.addthis.com',
				'path'  => '/live/redirect/',
				'query' => qr/(\A|[;&])url=/,
		},
		'AddThis 3' => {
				'host'  => 'api.addthis.com',
				'path'  => qr/^\/oexchange\//,
				'query' => qr/(\A|[;&])url=/,
		},
		'Add to any' => {
				'host'  => 'www.addtoany.com',
				'path'  => qr/^\/add_to\//,
				'query' => qr/(\A|[;&])linkurl=/,
		},
		'Amazon' => {
		'host'  => qr/(\.|\A)amazon-adsystem\.com$/,
				'path'  => '',
				'query' => '',
		},
		'Blogger' => {
				'host'  => qr/^(draft|www)\.blogger\.com$/,
				'path'  => qr/(\.g$|^\/comment\/frame\/)/,
				'query' => '',
		},
		'Cell Press' => {
				'host'  => 'www.cell.com',
				'path'  => '/action/showLogin',
				'query' => qr/(\A|[;&])redirectUri=/,
		},
		'ConstantContact' => {
				'host'  => 'visitor.constantcontact.com',
				'path'  => '/manage/optin/ea',
				'query' => qr/(\A|[;&])v=\b/,
		},
		'Creative Commons' => {
				'host'  => 'creativecommons.org',
				'path'  => qr/^\/licenses\/.+/,
				'query' => '',
		},
		'Delicious' => {
				'host'  => qr/^del(\.)?icio(\.)?us(\.com)?$/,
				'path'  => qr/^\/(post|save)$/,
				'query' => qr/(\A|[;&])url=/,
		},
		'Diaspora' => {
				'host'  => 'share.diasporafoundation.org',
				'path'  => '',
				'query' => qr/(\A|[;&])url=/,
		},
		'Digg' => {
				'host'  => qr/^(www\.)?digg\.com$/,
				'path'  => '/submit',
				'query' => qr/(\A|[;&])url=/,
		},
		'El País' => {
				'host'  => 'plus.elpais.com',
				'path'  => qr/^\/newsletters\//,
				'query' => qr/(\A|[;&])prm=/,
		},
		'Elsevier' => {
				'host'  => 'id.elsevier.com',
				'path'  => '',
				'query' => '',
		},
		'Facebook 1' => {
				'host'  => qr/(www\.)?facebook.com$/,
				'path'  => qr/^\/(sharer\/)?sharer?\.php$/,
				'query' => qr/(\A|[;&])u=/,
		},
		'Facebook 2' => {
				'host'  => qr/(www\.)?facebook.com/,
				'path'  => qr/^\/dialog\/(feed|share)/,
				'query' => qr/(\A|[;&])(href|link)=/,
		},
		'Facebook 3' => {
				'host'  => qr/(www\.)?facebook.com$/,
				'path'  => '/plugins/like.php',
				'query' => qr/(\A|[;&])(href|link)=/,
		},
		'Facebook 4' => {
				'host'  => qr/(www|[a-z]{2}-[a-z]{2})\.facebook.com$/,
				'path'  => '',
				'query' => '',
		},
		'Flipboard' => {
				'host'  => 'share.flipboard.com',
				'path'  => '/bookmarklet/popout',
				'query' => qr/(\A|[;&])url=/,
		},
		'Frontiers' => {
				'host'  => 'www.frontiersin.org',
				'path'  => '/people/login',
				'query' => '',
		},
		'Gab' => {
			'host'  => qr/^gab\.(ai|com)$/,
			'path'  => '/compose',
			'query' => qr/(\A|[;&])url=/,,
		},
		'Geocities' => {
				'host'  => qr/(\A|\.)geocities\.(co\.jp|(yahoo\.)?com)$/,
				'path'  => '',
				'query' => '',
		},
		'Gettr' => {
				'host'  => 'gettr.com',
				'path'  => '/share',
				'query' => '',
		},
		'Google Calendar' => {
				'host'  => 'www.google.com',
				'path'  => '/calendar/event',
				'query' => qr/(\A|[;&])action=/,
		},
		'Google Plus' => {
				'host'  => 'plus.google.com',
				'path'  => '',
				'query' => '',
		},
		'Google Marketing Platform' => {
				'host'  => qr/\.doubleclick\.net$/,
				'path'  => '',
				'query' => '',
		},
		'Google Syndication' => {
				'host'  => qr/\.googlesyndication\.com$/,
				'path'  => '',
				'query' => '',
		},
		'Google Tag Manager' => {
				'host'  => 'www.googletagmanager.com',
				'path'  => '/ns.html',
				'query' => qr/(\A|[;&])id=/,
		},
		'Government Site Builder' => {
				'host'  => '',
				'path'  => qr/^\/error_path\//, 
				'query' => '',
		},
		'Gustav Springer Verlag' => {
				'host'  => 'link.springer.com',
				'path'  => '/signup-login',
				'query' => '',
		},
		'Gustav Springer Verlag (Nature)' => {
				'host'  => qr/^idp(\.|-personal-authenticator\.springer)nature.com$/,
				'path'  => qr/^\/(auth\/personal\/springernature|gateway)$/,
				'query' => qr/(\A|[;&])redirect_uri=/,
		},
		'Heise' => {
				'host'  => 'www.heise.de',
				'path'  => qr/^\/sso\//,
				'query' => qr/(\A|[;&])forward=/,
		},
		'Instagram' => {
				'host'  => 'www.instagram.com',
				'path'  => qr/^\/(p|invites\/contact)\//,
				'query' => '',
		},
		'Ionos 1' => {
				'host'  => 'login.ionos.de',
				'path'  => '',
				'query' => '',
		},
		'Ionos 2' => {
				'host'  => qr/[\A \.](1and1|mywebsite)-editor\.com$/,
				'path'  => '',
				'query' => '',
		},
		'Jimdo 1' => {
				'host'  => 'a.jimdo.com',
				'path'  => qr/^\/app\/auth\//,
				'query' => '',
		},
		'Jimdo 2' => {
				'host'  => 'cms.e.jimdo.com',
				'path'  => qr/^\/app\/cms\//,
				'query' => '',
		},
		'Jimdo 3' => {
				'host'  => qr/\.jimdofree\.com$/,
				'path'  => '/login',
				'query' => '',
		},
		'Line 1' => {
				'host'  => 'line.me',
				'path'  => '/R/msg/text',
				'query' => '',
		},
		'Line 2' => {
				'host'  => 'access.line.me',
				'path'  => '',
				'query' => '',
		},
		'Linked In 1' => {
				'host'  => qr/^(www\.)?linkedin\.com$/,
				'path'  => '/shareArticle',
				'query' => qr/(\A|[;&])url=/,
		},
		'Linked In 2' => {
				'host'  => qr/^(www\.)?linkedin\.com$/,
				'path'  => '/sharing/share-offsite/',
				'query' => qr/(\A|[;&])url=/,
		},
		'Linked In 3' => {
				'host'  => qr/^(www\.)?linkedin\.com$/,
				'path'  => qr/\/signup\/.*/,
				'query' => '',
		},
		'Localhost' => {
				'host'  => qr/^([a-zA-Z\d][a-zA-Z\-\d\.]+\.)?localhost$/,
				'path'  => '',
				'query' => '',
		},
		'Mastodon 1' => {
				'host'  => qr/^[\w-\.]+\.social$/,
				'path'  => '/share',
				'query' => qr/(\A|[;&])text=/,
		},
		'Mastodon 2' => {
				'host'  => qr/^m(astodo|std)n\..+/,
				'path'  => '/share',
				'query' => qr/(\A|[;&])text=/,
		},
		'MastodonShare' => {
				'host'  => 'mastodonshare.com',
				'path'  => '',
				'query' => qr/(\A|[;&])url=/,
		},
		'Mendeley' => {
				'host'  => 'www.mendeley.com',
				'path'  => '/import/',
				'query' => qr/(\A|[;&])url=/,
		},
		'MeWe' => {
				'host'  => 'mewe.com',
				'path'  => '/share',
				'query' => qr/(\A|[;&])link=/,
		},
		'Microsoft' => {
				'host'  => 'login.microsoftonline.com',
				'path'  => '',
				'query' => '',
		},
		'Mix' => {
				'host'  => 'mix.com',
				'path'  => '/mixit',
				'query' => qr/(\A|[;&])url=/,
		},
		'Naver' => {
				'host'  => 'share.naver.com',
				'path'  => '/web/shareView.nhn',
				'query' => qr/(\A|[;&])url=/,
		},
		'netID' => {
				'host'  => 'broker.netid.de',
				'path'  => '/authorize',
				'query' => qr/(\A|[;&])client_id=/,
		},
		'Netvibes' => {
				'host'  => 'www.netvibes.com',
				'path'  => '/subscribe.php',
				'query' => qr/(\A|[;&])url=/,
		},
		'Ok.Ru 1' => {
				'host'  => qr/^((m|connect|www)\.)?o(dno)?k(lassniki)?\.ru$/,
				'path'  => qr/^\/dk(\;jsessionid=[\w\.]+)?$/,
				'query' => qr/(\A|[;&])st\.cmd=/,
		},
		'Ok.Ru 2' => {
				'host'  => qr/^((m|connect|www)\.)?o(dno)?k(lassniki)?\.ru$/,
				'path'  => qr/\/st\.cmd\//,
				'query' => '',
		},
		'Ok.Ru 3' => {
				'host'  => qr/^((m|connect|www)\.)?o(dno)?k(lassniki)?\.ru$/,
				'path'  => '/offer',
				'query' => qr/(\A|[;&])url=/,
		},
		'Open Authorization' => {
				'host'  => '',
				'path'  => qr/\/oauth2?\/.+/,
				'query' => qr/.+=.+/,
		},
		'Outlook Calendar' => {
				'host'  => qr/outlook\.(live|office)\.com$/,
				'path'  => qr/^\/owa\/?$/,
				'query' => qr/(\A|[;&])path=/,
		},
		'Parler' => {
				'host'  => 'parler.com',
				'path'  => '/new-post',
				'query' => qr/(\A|[;&])message=/,
		},
		'Pinterest' => {
				'host'  => qr/^(www\.)?pinterest.com$/,
				'path'  => qr/^\/pin\/create\/(link|bookmarklet|button)\/?$/,
				'query' => '',
		},
		'Pocket' => {
				'host'  => 'getpocket.com',
				'path'  => qr/^\/(edit|save)$/,
				'query' => qr/(\A|[;&])url=/,
		},
		'Reddit' => {
				'host'  => qr/^(www\.)?reddit\.com$/,
				'path'  => '/submit',
				'query' => qr/(\A|[;&])url=/,
		},
		'Science' => { 
				'host'  => 'www.science.org',
				'path'  => '/action/ssostart',
				'query' => '',
		},
		'Skype' => {
				'host'  => 'web.skype.com',
				'path'  => '/share',
				'query' => qr/(\A|[;&])url=/,
		},
		'Snapchat' => {
				'host'  => 'www.snapchat.com',
				'path'  => qr/^\/add\/.+/,
				'query' => '',
		},
		'Stack Overflow 1' => {
				'host'  => qr/[^|\.](askubuntu|serverfault|stack(exchange|overflow)|superuser)\.com$/,
				'path'  => qr/^\/users\/(login|signup)$/,
				'query' => '',
		},
		'Stack Overflow 2' => {
				'host'  => 'stackoverflow.com',
				'path'  => '/teams/create/free',
				'query' => '',
		},
		'Stumble Upon' => {
				'host'  => 'www.stumbleupon.com',
				'path'  => '/submit',
				'query' => qr/(\A|[;&])url=/,
		},
		'Telegram' => {
				'host'  => qr/^t(elegram)?\.me$/,
				'path'  => '/share/url',
				'query' => '',
		},
		'Telekom' => {
				'host'  => qr/login\.idm\.telekom\.com$/,
				'path'  => '',
				'query' => '',
		},
		'T-Online' => {
				'host'  => 'login.t-online.de',
				'path'  => '',
				'query' => '',
		},
		'Technorati' => {
				'host'  => 'technorati.com',
				'path'  => '/faves',
				'query' => '',
		},
		'Tumblr 1' => {
				'host'  => qr/^(www\.)?tumblr\.com$/,
				'path'  => qr/^\/share(\/link)?/,
				'query' => qr/(\A|[;&])u(rl)?=/,
		},
		'Tumblr 2' => {
				'host'  => qr/^(www\.)?tumblr\.com$/,
				'path'  => '/widgets/share/tool',
				'query' => qr/(\A|[;&])canonicalUrl=/,
		},
		# https://developer.twitter.com/en/docs/twitter-for-websites/web-intents/overview
		'Twitter 1' => {
				'host'  => qr/^(www\.)?(twitter|x)\.com$/,
				'path'  => qr/^\/intent\/((re)?tweet|like|user|follow)\/?$/,
				'query' => '',
		},
		'Twitter 2' => {
				'host'  => qr/^(www\.)?(twitter|x)\.com$/,
				'path'  => '/share',
				'query' => qr/(\A|[;&])(url|text)=/,
		},
		'Twitter 3' => {
				'host'  => qr/^(www\.)?(twitter|x)\.com$/,
				'path'  => '/home',
				'query' => '',
		},
		'Twitter 4' => {
				'host'  => qr/^((www|mobile)\.)?(twitter|x)\.com$/,
				'path'  => '',
				'query' => '',
		},
		'Virtual Minds' => {
		'host'  => qr/(\.|\A)adition\.com$/,
				'path'  => '',
				'query' => '',
		},
		'VK' => {
				'host'  => qr/vk(ontakte)?\.(ru|com)$/,
				'path'  => '/share.php',
				'query' => qr/(\A|[;&])url=/,
		},
		'Wayback Machine 1' => {
				'host'  => 'web.archive.org',
				'path'  => '',
				'query' => '',
		},
		'Wayback Machine 2' => {
				'host'  => 'archive.org',
				'path'  => qr/^\/(details|includes|web)\//,
				'query' => '',
		},
		'Wayback Machine 3' => {
				'host'  => 'faq.web.archive.org',
				'path'  => '',
				'query' => '',
		},
		'Weibo' => {
				'host'  => 'service.weibo.com',
				'path'  => '/share/share.php',
				'query' => qr/(\A|[;&])url=/,
		},
		'WhatsApp 1' => {
				'host'  => qr/^(api|web)\.whatsapp\.com$/,
				'path'  => '/send',
				'query' => qr/(\A|[;&])text=/,
		},
		'WhatsApp 2' => {
				'host'  => 'wa.me',
				'path'  => '',
				'query' => '',
		},
		'Wiley 1' => {
				'host'  => qr/^(.+\.)?onlinelibrary.wiley.com$/,
				'path'  => '/action/showLogin',
				'query' => '',
		},
		'Wiley 2' => {
				'host'  => 'authorservices.wiley.com',
				'path'  => '',
				'query' => '',
		},
		'WordPress 1' => {
				'host'  => '',
				'path'  => qr/\/wp-(admin\/|login\.php$)/,
				'query' => '',
		},
		'WordPress 2' => {
				'host'  => '',
				'path'  => '',
				'query' => qr/(\A|[;&])share=(facebook|email|instagram|jetpack-whatsapp|linkedin|mastodon|nextdoor|pinterest|pocket|reddit|telegram|tumblr|twitter)\b/,
		},
		'WordPress 3' => {
				'host'  => 'widgets.wp.com',
				'path'  => '/likes/index.html',
				'query' => qr/(\A|[;&])ver=/,
		},
		'XING 1' => {
				'host'  => qr/^(www\.)?xing.com$/,
				'path'  => '/spi/shares/new',
				'query' => qr/(\A|[;&])url=/,
		},
		'XING 2' => {
				'host'  => qr/^(www\.)?xing.com$/,
				'path'  => '/app/user',
				'query' => qr/(\A|[;&])op=share\b/,
		},
		'XING 3' => {
				'host'  => qr/^(www\.)?xing.com$/,
				'path'  => '/social/share/spi',
				'query' => qr/(\A|[;&])url=/,
		},
		'XING 4' => {
				'host'  => qr/^(www\.)?xing.com$/,
				'path'  => qr/^\/social_plugins\/share(\/new)?\/?/,
				'query' => qr/(\A|[;&])url=/,
		},
		'Yahoo' => {
				'host'  => 'add.my.yahoo.com',
				'path'  => qr/\/(content|rss)/,
				'query' => qr/(\A|[;&])url=/,
		},
		'Yahoo Calendar' => {
				'host'  => 'calendar.yahoo.com',
				'path'  => '/',
				'query' => qr/(\A|[;&])ST=/,
		},
		'Yandex' => {
				'host'  => qr/^(oauth|passport)\.yandex\.ru$/,
				'path'  => qr/^\/auth(orize)?$/,
				'query' => qr/(\A|[;&])client_id=/,
		},
		'?' => {
				'host'  => '',
				'path'  => qr/\/(account|anmelden|auth(enticate|orize)?|log[-_]?in|register|sign[-_]?(in|up))(\/|\.\w+)?$/i,
				'query' => '',
		},
	);
		
	#say Dumper(%blacklist);
}

# like PHP
sub trim {
	my $trim = shift;
	$trim =~ s/^\s+//;
	$trim =~ s/\s+$//;
	return $trim;
}