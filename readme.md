# archive.pl

*A script for archiving URL sets (HTML, PDF) in the [Internet Archive](https://archive.org).*

© 2015-2020 Ingram Braun [https://ingram-braun.net/](https://ingram-braun.net/#ib_campaign=archive-pl-2.1&ib_medium=repository&ib_source=readme&ib_content=copyright)

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program. If not, see <http://www.gnu.org/licenses/>.

## Requirements

Perl 5.24 (earlier versions not tested but it is likely to work with every build that is capabale of getting the required modules installed). If there are issues with installing the `XMLRPC::lite` module, do it with CPAN's `notest` pragma.

## Usage

Collect URLs you want to archive in file `urls.txt` separated by one or more line breaks and UTF-8-encoded and call `perl archive.pl`. The script does to things: it fetches the URLs and extracts some metadata (works with HTML and PDF). It submits them to Internet Archive. Then it generates a HTML file with a link list that you may post to your blog or use autmoated submission to WordPress. Alternatively you can get the link list as Atom feed. If login credentials are provided but no FTP host, it is posted to WordPress. The WP URL must point to the `xmlrpc.php`. Additionally you can post the links on Twitter. Regardless of the format you can upload the file on a server via FTP.

Internet Archive has a submission limit of 15 URLs per minute per IP. Set an appropriate delay (at least five seconds) to meet it. If you want to be faster, set a proxy server which rotates IPs. This is fi. possible with TOR as service (the TOR browser on Windows does not work here!). Set `MaxCircuitDirtiness 10` in the configuration file (`/path/to/torrc`) to rotate IPs every ten seconds.

There are several optional switches

`-a` output as Atom feed instead of HTML

`-c <creator>` name of feed creator (feed only)

`-d <path>` FTP path

`- D` Debug mode - don't save to Internet Archive

`-f <filename>` name of input file if other than `urls.txt`

`-h` Show commands

`-i <title>` Feed or HTML title

`-k <consumer key>` Twitter consumer key

`-l` save linked documents

`-n <username>` FTP or WordPress user

`-o <host>` FTP host

`-p <password>` FTP or WordPress password

`-P <proxy>` A proxy, fi. socks4://localhost:9050 for TOR service

`-r` obey `robots.txt`

`-s` save feed in Wayback machine

`-t <access token>` Twitter access token

`-T <seconds>` delay per URL in seconds to respect IA's request limit

`-u <URL>` Feed or WordPress (`xmlrpc.php`) URL

`-w` *deprecated*

`-x <secret consumer key>` Twitter secret consumer key

`-y <secret access token>` Twitter secret access token

`-z <time zone>` Time zone (WordPress only)

## Changelog


### v2.2

- Fixed image data URLs bug.
- Removed TLS from Wayback URLs (too many protocol errors).
- Added `mirror.pl`.

### v2.1

- Introduced option `-P` to connect to a proxy server that can rotate IPs (fi. TOR).
- User agent bug in `LWP::UserAgent` constructor call fixed.
- `-T` is able to eat floats.
- Screen logging enhanced (total execution time and total number of links).
- IA JSON parsing more reliable.

### v2.0

- Script can save all linked URLs, too (IA has restricted this service to logged-in users running JavaScript).
- Debug mode (does not save to IA).
- WordPress bug fixed (8-Bit ASCII in text lead to database error).
- Ampersand bug in 'URL available' request fixed.
- Trim metadata.
- Disregard `robots.txt` by default.

### v1.8

- Post HTML outfile to WordPress
- Wayback machine saves all documents linked in the URL if it is HTML (Windows only).
- Time delay between processing of URLs because Internet Archive set up a request limit.
- Version and help switches.

### v1.7

- Tweet URLs.
- Enhanced handling of PDF metadata.
- Always save biggest Twitter image.

### v1.6

Not published.

### v1.5

- Supports `wget` and `PowerShell` (w flag).
- Displays the closest Wayback copy date.
- Better URL parsing.
- Windows executable only 64 bit since not all modules install properly on 32.

### v1.4

 - Enhanced metadata scraping.
 - Archive images from Twitter in different sizes.
 - Added project page link to outfile.
 - Remove UTF-8 BOM from infile.
 - User agent avoids strings `archiv` and `wayback`.
 - Internet Archive via TLS URL.
 - Thumbnail if URL points to an image.

### v1.3

 - Debugging messages removed.
 - Archive.Org URL changed.

### v1.2

 - Internationalized domain names (IDN) allowed in URLs.
 - Blank spaces allowed in URLs.
 - URL list MUST be in UTF-8 now!
 - Only line breaks allowed as list separator in URL list.

### v1.1

 - Added workaround for ampersand bug on Windows in module `Browser::Open` <https://rt.cpan.org/Ticket/Display.html?id=117917&results=035ab18171a4a673f347e0ca5a8629f4>

## Project Page

[https://ingram-braun.net/erga/archive-pl-a-perl-script-for-archiving-url-sets-in-the-internet-archive/](https://ingram-braun.net/erga/archive-pl-a-perl-script-for-archiving-url-sets-in-the-internet-archive/#ib_campaign=archive-pl-2.1&ib_medium=repository&ib_source=readme&ib_content=projectpage)

## Windows Binaries

Binaries Windows 64 bit (XP or higher) can get obtained from the project page [https://ingram-braun.net/erga/archive-pl-a-perl-script-for-archiving-url-sets-in-the-internet-archive/](https://ingram-braun.net/public/programming/perl/wayback-url-robot-html/#ib_campaign=archive-pl-2.1&ib_medium=repository&ib_source=readme&ib_content=binaries)
