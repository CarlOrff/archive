#!/usr/bin/perl
-T;

##################################################################################################
#
# archive.pl
#
# (c) 2015-2016 by Ingram Braun (https://ingram-braun.net/)
#
# PURPOSE: extracts metada from HTML and PDF URLs, stores them in the Internet Archive
# (https://archive.org/) and generates a report (HTML or Atom) that is suitable for posting it 
# to a blog or as Atom feed.
#
# USAGE: store URLs as space-separated list in file urls.txt and start archive.pl
#    Optional arguments:
#               -a              Atom feed instead of HTML output
#               -c <creator>    Name of the feed author (feed only)
#               -f <filename>   Other input file name than urls.txt
#               -u <URL>        Feed URL (feed only)
#
#
# LICENSE: GNU GENERAL PUBLIC LICENSE v.3
#
# PROJECT PAGE: https://ingram-braun.net/public/programming/perl/wayback-url-robot-html/
#
##################################################################################################

use feature 'unicode_strings';
use strict;
binmode STDOUT, ":utf8";

#use warnings;
use Data::Dumper;

use Browser::Open qw( open_browser );
use DateTime;
use DateTime::Format::W3CDTF;
use FileHandle;
use Getopt::Std;
use HTML::Entities;
use List::Util qw( reduce );
use LWP::RobotUA;
use WWW::RobotRules;
use Web::Scraper;
use XML::Atom::SimpleFeed;

##################################################################################################
# global variables
##################################################################################################

my $botname = 'archive.pl/0.99';
my @urls;
my $author_delimiter = '/';

# user agent string
my $scripturl = 'https://ingram-braun.net/public/programming/perl/wayback-url-robot-html/';
my $ua_string = "Mozilla/5.0 (compatible; $botname; +$scripturl)";

# fetch options
my %opts;
getopts('ac:f:u:', \%opts);

my $creator = ($opts{c} && length $opts{c} > 0) ?  $opts{c} : "Ingram Braun";
my $infile = ($opts{f} && length $opts{f} > 0) ?  $opts{f} : "urls.txt";
$scripturl = { rel => 'self', href => $opts{u}, } if $opts{a} && $opts{u} && length $opts{c} > 0;

my $outfile = ($opts{a}) ? XML::Atom::SimpleFeed->new(
     id => $$scripturl{href},
     title   => 'Archived URLs',
     link    => encode_entities($scripturl),
     updated => DateTime::Format::W3CDTF->new()->format_datetime(DateTime->now),
     author  => $creator, # needed since it is not sure that all entries have an author
     generator  => $botname,
 ) : "<!doctype html>\n<head>\n<meta http-equiv='Content-Type' content='text/html; charset=UTF-8'>\n<meta name='generator' content='$botname'>\n<link rel='help' href='$scripturl'>\n<title>$botname result</title>\n</head>\n<body>\n\n<ul>\n";


##################################################################################################
# read URL list from file (space separated list)
##################################################################################################

my $fh = FileHandle->new($infile, "r");
if (defined $fh) {
	while(<$fh>) {
		push(@urls,split(/\s+/,$_));
	}
	undef $fh;       # automatically closes the file
}

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

##################################################################################################
# loop through URLs
##################################################################################################

foreach my $url (@urls) {

	# don't fetch empty URLs
	next if length($url) < 1;
	
	# HTML encode URL
	my $encoded_url = encode_entities($url);
	
	# status message
	print "\nfetching ", $url, "\n";
	
	# fetch URL
	my $r = $ua->request(HTTP::Request->new( GET => $url ));
    
    if ($r->is_success) {
	
		print "successfull!\n";
		
		my($title, $description, $author, $language);
		
##################################################################################################
# HTML
##################################################################################################

		if ($r->header('content-type') =~ /(ht|x)ml/i) {
        
            # contains() is case sensitive.
			my $scraper = scraper {
				# title
				process_first '//meta[contains(@property,"og:title")]', "open_graph_title" => '@content';
				process_first '//meta[contains(@name,"DC.title")]', "dublin_core_title" => '@content';
				process_first '//meta[contains(@property,"dc:title")]', "dublin_core_title2" => '@content';
				process_first '//meta[contains(@name,"twitter:title")]', "twitter_title" => '@content';
				process_first '//h3[contains(@class,"post-title entry-title")]', "blogspot_title" => "TEXT"; # Google Blogger
				process_first "title", "title" => "TEXT";
				process_first "h1", "h1" => "TEXT";
				process '//*[starts-with(@itemprop,"headlinie")]', "schema_title" => '@content';
				# description
				process_first '//meta[contains(@property,"og:description")]', "open_graph_description" => '@content';
				process_first '//meta[contains(@name,"DC.description")]', "dublin_core_description" => '@content';
				process_first '//meta[contains(@name,"dc:description")]', "dublin_core_description2" => '@content';
				process_first '//meta[contains(@name,"DCTERMS.abstract")]', "dublin_core_abstract" => '@content';
				process_first '//meta[contains(@property,"dcterms:abstract")]', "dublin_core_abstract2" => '@content';
				process_first '//meta[contains(@name,"twitter:description")]', "twitter_description" => '@content';
				process_first '//meta[starts-with(@name,"description")]', "meta_description" => '@content';
				process_first '//meta[starts-with(@name,"Description")]', "meta_description2" => '@content';
				# tscrap authors
				# we only look for Dublin Core and XML elements since Open Graph stores an URL, Twitter an account and Schema.Org needs enhanced parsing
				process '//meta[contains(@name,"DC.creator")]', "dublin_core_author[]" => '@content';
				process '//meta[contains(@name,"DC.contributor")]', "dublin_core_author[]" => '@content';
				process '//meta[contains(@property,"dc:creator")]', "dublin_core_author2[]" => '@content';
				process '//meta[contains(@property,"dc:contributor")]', "dublin_core_author2[]" => '@content';
				process '//meta[starts-with(@name,"Creator")]', "meta_author[]" => '@content';
				process '//meta[starts-with(@name,"Author")]', "meta_author[]" => '@content';
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
			my $scraped = $scraper->scrape($r);
			#print Dumper($scraped);
			
			# we assume that social media titles are better than HTML titles
			print "title ";
			if (exists($scraped->{'open_graph_title'})) {
				$title = $scraped->{'open_graph_title'};
			}
			elsif (exists($scraped->{'twitter_title'})) {
				$title = $scraped->{'twitter_title'};
			}
			elsif (exists($scraped->{'dublin_core_title'})) {
				$title = $scraped->{'dublin_core_title'};
			}
			elsif (exists($scraped->{'dublin_core_title2'})) {
				$title = $scraped->{'dublin_core_title2'};
			}
			elsif (exists($scraped->{'blogspot_title'})) {
				$title = $scraped->{'blogspot_title'};
			}
			elsif (exists($scraped->{'h1'})) {
				$title = $scraped->{'h1'};
			}
			elsif (exists($scraped->{'schema_title'})) {
				$title = $scraped->{'schema_title'};
			}
			# the title element sometimes holds the site name
			elsif (exists($scraped->{'title'})) {
				$title = $scraped->{'title'};
			}
			else {
				$title = $url;
			}
			print length($title), " characters\n";
			
			# we assume that the longest description is the best
			print "description ";
			$description = reduce { length $a > length $b ? $a : $b } map {$_ if defined $_} ($scraped->{'open_graph_description'},$scraped->{'dublin_core_description'},$scraped->{'dublin_core_description2'},$scraped->{'twitter_description'},$scraped->{'dublin_core_abstract'},$scraped->{'dublin_core_abstract2'},$scraped->{'meta_description'},$scraped->{'meta_description2'});
			print length($description), " characters\n";
			
			# join authors
			print "authors ";
			if (exists($scraped->{'dublin_core_author'})) {
				$author = join($author_delimiter,@{$scraped->{'dublin_core_author'}});
			}
			if (exists($scraped->{'dublin_core_author2'})) {
				$author = join($author_delimiter,@{$scraped->{'dublin_core_author2'}});
			}
			elsif (exists($scraped->{'meta_author'})) {
				$author = join($author_delimiter,@{$scraped->{'meta_author'}});
			}
			elsif (exists($scraped->{'xml_author'})) {
				$author = join($author_delimiter,@{$scraped->{'xml_author'}}),
			}
			else {
				$author = '';
			}
			print length($author), " characters\n";
			
			# record language
			print "language ";
			if (defined $scraped->{'html_lang'}) {
				$language = $scraped->{'html_lang'};
			}
			elsif (defined $scraped->{'title_lang'}) {
				$language = $scraped->{'title_lang'};
			}
			elsif (defined $scraped->{'body_lang'}) {
				$language = $scraped->{'body_lang'};
			}
			elsif (defined $scraped->{'meta_lang'}) {
				$language = $scraped->{'meta_lang'};
			}
			elsif (defined $scraped->{'meta_lang2'}) {
				$language = $scraped->{'meta_lang2'};
			}
			else {
				$language = '';
			}
			print length($language), " characters\n";
			
			#add to list
            if ($opts{a}) {
                $outfile->add_entry(
                    author => encode_entities($author),
                    link => $encoded_url,
                    summary => encode_entities($description),
                    title => encode_entities($title),
                );
            }
            else {
                $outfile .= '<li' . (length($language) > 1 ? ' lang="'.$language.'"' : '') . '>' . (length($author) > 1 ? encode_entities($author).' ' : '') . '<a ' . (length($language) > 1 ? 'hreflang="'.$language.'" ' : '') . 'href="' . $encoded_url . '">' . HTML_format_title($title) . '</a>' . HTML_format_description($description) . "</li>\n";
            }
			
		}
		
##################################################################################################
# PDF
##################################################################################################

		elsif ($r->header('content-type') =~ /pdf$/i) {
        
		my $content = $r->content;
		$content =~ s/\n//g;

			# PDF metadata are stored in plain text or XML, so we can process them by common string operations.
		
			# Find title
			print "title ";
			# try PDF core
			if ($content =~ /\/Title\s*\((.+?)\)/) {
				$title = $1;
			}
			# try Dublin Core as attribute
			elsif ($content =~ /\bdc\:title\s?=\s?("(.+?)"|'(.+?)')/i) {
				$title = $+;
			}
			# try Dublin Core as tag
			elsif ($content =~ /<dc\:title>\s*(.*?)\s*<\/dc\:title>/i) {
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
			if ($content =~ /\bdc\:description\s?=\s?("(.+?)"|'(.+?)')/i) {
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
			if ($content =~ /\/Author\s*\((.+?)\)/) {
				$authors{$1}++;
			}
			# try XAP
			if (scalar keys %authors == 0) {
				while ($content =~ /\bxap\:Author\s?=\s?("(.+?)"|'(.+?)')/gi) {
					my $hit = $+;
					chop($hit);
					$hit =~ s/^.+?["']//;
					last if exists($authors{$hit}); # avoid infinite loop
					$authors{$hit}++;
				}
			}
			# try Dublin Core as attribute
			if (scalar keys %authors == 0) {
				while ($content =~ /\bdc\:c(rea|ontribu)tor\s?=\s?("(.+?)"|'(.+?)')/gi) {
					my $hit = $+;
					chop($hit);
					$hit =~ s/^.+?["']//;
					last if exists($authors{$hit}); # avoid infinite loop
					$authors{$hit}++;
				}
			}
			# try Dublin Core as tag
			if (scalar keys %authors == 0) {
				while ($content =~ /<dc\:c(rea|ontribu)tor>\s*(.*?)\s*<\/dc\:c(rea|ontribu)tor>/gi) {
					my $hit = $2;
					$hit =~ s/\s*<\/?[a-z].*?>\s*//g;
					last if exists($authors{$hit}); # avoid infinite loop
					$authors{$hit}++;
				}
			}
			# try PDF/X
			if (scalar keys %authors == 0) {
				while ($content =~ /<pdfx\:myAuthorName>(.+?)<\/pdfx\:myAuthorName>/gi) {
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
                    author => encode_entities($author),
                    link => $encoded_url,
                    summary => encode_entities($description),
                    title => encode_entities($title),
                );
            }
            else {
                $outfile .= '<li>' . (length $author > 0 ? encode_entities($author).' ' : '') . '<a href="' . $encoded_url . '" type="application/pdf">' . HTML_format_title($title) . '</a>&nbsp;<sup>[PDF]</sup>' . HTML_format_description($description) . "</li>\n";
            }
		}
		
		# other MIME types
		else {
		
			if ($opts{a}) {
                $outfile->add_entry(link => $encoded_url);
            }
            else {
                $outfile .= '<li><a href="' . $encoded_url . '">' . $encoded_url . '</a></li>\n';
            }
		}
		
	}
	
	# URL not fetched
	else {
	
		print "failed!\n";
        
        if ($opts{a}) {
            $outfile->add_entry(link => $encoded_url);
        }
        else {
            $outfile .= '<li><a href="' . $encoded_url . '">' . $encoded_url . '</a></li>\n';
        }
	}

##################################################################################################
# save in Wayback Machine
# blocked by robots.txt, therefore we do it in a browser
##################################################################################################

	print "submit to Internet Archive\n";
	open_browser('http://web.archive.org/save/' . $url);
	
} # main loop

##################################################################################################
# print file
##################################################################################################

# close list
$outfile .= "</ul>\n\n</body>" if !$opts{a};

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
# Subroutines
##################################################################################################

# arg 1: title string
# returns formatted title string
sub HTML_format_title {
	return $_[0] if $_[0] =~ /^[a-z]+\:\/\//i; # is URL
	return '<cite>' . encode_entities($_[0]) . '</cite>';
}

# arg 1: description string
# returns formatted description string
sub HTML_format_description {
	return $_[0] if length $_[0] == 0; # is empty
	return "<br />\n" . encode_entities($_[0]);
}