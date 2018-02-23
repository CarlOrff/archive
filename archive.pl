#!/usr/bin/perl
-T;

##################################################################################################
#
# archive.pl
#
# (c) 2015-2017 by Ingram Braun (https://ingram-braun.net/)
#
# PURPOSE: extracts metada from HTML and PDF URLs, stores them in the Internet Archive
# (https://archive.org/) and generates a report (HTML or Atom) that is suitable for posting it 
# to a blog or as Atom feed. The report can get ftp'ed.
#
# USAGE: store URLs as break-separated list in file urls.txt and start archive.pl
#    Optional arguments:
#               -a              Atom feed instead of HTML output
#               -c <creator>    Name of the feed author (feed only)
#               -d <path>       FTP path
#               -f <filename>   Other input file name than urls.txt
#               -n <username>   FTP user
#               -o <host>       FTP host
#               -p <password>   FTP password
#               -s              Save feed in Wayback machine (feed only)
#               -u <URL>        Feed URL (feed only)
#
#
# LICENSE: GNU GENERAL PUBLIC LICENSE v.3
#
# PROJECT PAGE: https://ingram-braun.net/public/programming/perl/wayback-url-robot-html/
#
##################################################################################################

use strict;
use utf8::all;

#use diagnostics;
#use warnings;
#use Data::Dumper;

use Browser::Open qw( open_browser );
use DateTime;
use DateTime::Format::W3CDTF;
use FileHandle;
use GD;
use Getopt::Std;
use HTML::Entities;
use HTML::Strip;
use Image::Info qw( dim image_info html_dim );
use Image::Thumbnail;
use List::Util qw( reduce );
use LWP::RobotUA;
use MIME::Base64;
use Net::FTP;
use Net::IDN::Encode 'domain_to_ascii';
use URI::Encode;
use WWW::RobotRules;
use Web::Scraper;
use XML::Atom::SimpleFeed;

##################################################################################################
# global variables
##################################################################################################

my $botname = 'archive.pl-1.4';
my @urls;
my $author_delimiter = '/';

# user agent string
my $atomurl = "https://ingram-braun.net/public/programming/perl/wayback-url-robot-html/#ib_campaign=$botname&ib_medium=atom&ib_source=outfile";
my $htmlurl = "https://ingram-braun.net/public/programming/perl/wayback-url-robot-html/#ib_campaign=$botname&ib_medium=html&ib_source=outfile";
my $scripturl = 'http://bit.ly/2FbNxn0';
my $ua_string = "Mozilla/5.0 (compatible; +$scripturl)";

my $wayback_url = 'https://web.archive.org/save/';

# fetch options
my %opts;
getopts('ac:d:f:n:o:p:su:', \%opts);

# save old feed
open_browser($wayback_url . $opts{u}) if length $opts{u} > 0 && $opts{s} && $opts{a};

my $creator = ($opts{c} && length $opts{c} > 0) ?  $opts{c} : "Ingram Braun";
my $infile = ($opts{f} && length $opts{f} > 0) ?  $opts{f} : "urls.txt";
my %atomurl = ($opts{u} && length $opts{u} > 0) ? ( 'rel' => 'self', 'href' => encode_entities($opts{u}), ) : ( 'href' => $atomurl, ) if $opts{a};

my $outfile = ($opts{a}) ? XML::Atom::SimpleFeed->new(
     id => $atomurl{href},
     title   => 'Archived URLs',
     link    => \%atomurl,
     updated => DateTime::Format::W3CDTF->new()->format_datetime(DateTime->now), 
     author  => $creator, # needed since it is not sure that all entries have an author
     generator  => $botname,
 ) : "<!doctype html>\n<head>\n<meta http-equiv='Content-Type' content='text/html; charset=UTF-8'>\n<meta name='generator' content='$botname'>\n<link rel='help' href='$htmlurl'>\n<title>$botname result</title>\n</head>\n<body>\n\n<ul>\n";


##################################################################################################
# read URL list from file (line break separated list)
##################################################################################################

my $fh = FileHandle->new($infile, "r");
binmode($fh, ":utf8");
if (defined $fh) {
	
	while(<$fh>) {
		push(@urls,split(/\n+/,$_));
	}
	
	#remove UTF BOM
	$urls[0] =~ s/^\x{FEFF}//;
	$urls[0] =~ s/^\N{U+FEFF}//;
	$urls[0] =~ s/^\N{ZERO WIDTH NO-BREAK SPACE}//;
	$urls[0] =~ s/^\N{BOM}//;
	
	undef $fh;       # automatically closes the file

}
else { die "Could not open $infile"; }

##################################################################################################
# initialize robot object
##################################################################################################

my $ua = LWP::RobotUA->new($ua_string, 'bot@example.com');
$ua->delay(0); # minutes (0 because we don't crawl domains recursively)
$ua->ssl_opts(  # we don't verify hostnames of TLS URLs
    verify_mode   => 'SSL_VERIFY_PEER',
    verify_hostname => 0, 
);
$ua->rules(WWW::RobotRules->new($ua_string)); # obey robots.txt

# Save all size of twitter images

##################################################################################################
# loop through URLs
##################################################################################################

foreach my $url (@urls) {

	# don't fetch empty URLs
	next if length $url < 1;
    
    # remove hash part:
    $url =~ s/#.+//;
    
    $url =~ /(.+?\:\/\/)(.+?)($|\/.*)/;
    my ($scheme,$host,$path_query) = ($1,$2,$3);
    
    # remove high chars in path and query params:
    $path_query = URI::Encode->new({double_encode => 0})->encode($path_query);
    
    # convert IDN to ACE
    $host = domain_to_ascii( $host );
    
    # now use prepared URL
    $url = $scheme.$host.$path_query;
	
	# HTML encode URL
	my $encoded_url = encode_entities( $url );
	
	# status message
	print "\nfetching ", $url, "\n";
	
	# fetch URL
	my $r = $ua->request(HTTP::Request->new( GET => $url ));
    
    if ($r->is_success) {
	
		print "successfull!\n";
		
		my($title, $description, $author, $language, $content);
		
		$content = $r->content;
        	
##################################################################################################
# HTML
##################################################################################################

		if ($r->header('content-type') =~ /(ht|x)ml/i) {
		
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
			print "title ";
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
			print length($title), " characters\n";
			
			# we assume that the longest description is the best
			print "description ";
			$description = reduce { length $a > length $b ? $a : $b } map {$_ if defined $_} ($scraper->{'open_graph_description'},$scraper->{'dublin_core_description'},$scraper->{'dublin_core_description2'},$scraper->{'twitter_description'},$scraper->{'dublin_core_abstract'},$scraper->{'dublin_core_abstract2'},$scraper->{'meta_description'},$scraper->{'meta_description2'});
			print length($description), " characters\n";
			
			# join authors
			print "authors ";
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
			print length($author), " characters\n";
			
			# record language
			print "language ";
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
			print length($language), " characters\n";
			
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
                $outfile .= '<li>PDF:&nbsp;' . (length $author > 0 ? encode($author).' ' : '') . '<a href="' . $encoded_url . '" type="application/pdf">' . HTML_format_title($title) . '</a>&nbsp;' . HTML_format_description($description) . "</li>\n";
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
			
			# make title
			$title = "IMAGE (" . $origimg->{'file_type'} . "$width × $height) $encoded_url";
			
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
			$description = '<img ' . $w . $h . ' src="data:image/pgn;base64,' .  encode_base64($thumb) . '"/>' if length $thumb > 0;
		
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
                $outfile .= '<li><a href="' . $encoded_url . '" type="' . $r->header('content-type') . '">' . encode_entities($title) . '</a>&nbsp;' . $description . "</li>\n";
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
	
		print "failed!\n";
        my $warning = 'WARNING: cannot fetch ' . $encoded_url;
        
        if ($opts{a}) {
            $outfile->add_entry(link => $encoded_url, title => $warning);
        }
        else {
            $outfile .= '<li><a href="' . $encoded_url . '">' . $warning . '</a></li>\n';
        }
	}

##################################################################################################
# save in Wayback Machine
# blocked by robots.txt, therefore we do it in a browser
##################################################################################################

	print "submit to Internet Archive\n";
    # We must escape the ampersands in parameter lists on Windows computers due to a bug
    # in Browser:Open https://rt.cpan.org/Ticket/Display.html?id=117917&results=035ab18171a4a673f347e0ca5a8629f4
	
	my %urls; # here we can save known URL formats in different variants, fi. images in different sizes.

	# Twitter images in different sizes
	if ( $url =~ /(https:\/\/pbs\.twimg\.com\/media\/[\w-]+)(\.|\?format=)([a-z]{3})/i ) {
	
		$urls{"$1.$3"}++;
		$urls{"$1.$3:large"}++;
		$urls{"$1?format=$3"}++;
		$urls{"$1?format=$3&name=small"}++;
		$urls{"$1?format=$3&name=medium"}++;
		$urls{"$1?format=$3&name=large"}++;
	}
	else { $urls{$url}++; }
	
	foreach my $ia (keys %urls) {
		$ia =~ s/(?<!\^)&/^&/g if index($^O,'MSWin32') > -1;
		open_browser($wayback_url.$ia);
	}
	
} # main loop

##################################################################################################
# print file
##################################################################################################

# close list
$outfile .= "</ul>\n<hr><p>Generated with <a href='$htmlurl'>$botname</a></p></body>" if !$opts{a};

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
# Subroutines
##################################################################################################


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

#checks if a scraper result is true
sub check_scraped {
	my $scraped = shift;
	my $tag = shift;
	return exists ($scraped->{$tag}) && length $scraped->{$tag} > 0;
}