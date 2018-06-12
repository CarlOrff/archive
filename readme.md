# archive.pl

*A script for archiving URL sets (HTML, PDF) in the [Internet Archive](https://archive.org).*

Copyright (C) 2015-2018 Ingram Braun [https://ingram-braun.net/](https://ingram-braun.net/#ib_campaign=$archive-pl-1.4&ib_medium=repository&ib_source=readme)

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program. If not, see <http://www.gnu.org/licenses/>.

## Requirements

Perl 5.24 (earlier versions not tested but it is likely to work with every build that is capabale of getting the required modules installed)

## Usage

Collect URLs you want to archive in file `urls.txt` separated by one or more line breaks and UTF-8-encoded and call `perl archive.pl`. The script does to things: it fetches the URLs and extracts some metadata (works with HTML and PDF). It submits them to Internet Archive by opening them in a browser. This is necessary because Internet Archive blocks robots globally. Then it generates a HTML file with a link list that you may post to your blog. Alternatively you can get the link list as Atom feed. Regardless of the format you can upload the file on a server via FTP.

There are several optional switches

`-a` output as Atom feed instead of HTML

`-c <creator>` name of feed creator (feed only)

`-d <path>` FTP path

`-f <filename>` name of input file if other than `urls.txt`

`-n <username>` FTP user

`-o <host>` FTP host

`-p <password>` FTP password

`-s` Save feed in Wayback machine (feed only)

`-u <URL>` feed URL (feed only)

## Changelog

### v1.5

- supports `wget` and `PowerShell` (w flag).
- displays the closest Wayback copy date.

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

[https://ingram-braun.net/public/programming/perl/wayback-url-robot-html/](https://ingram-braun.net/public/programming/perl/wayback-url-robot-html/#ib_campaign=$archive-pl-1.4&ib_medium=repository&ib_source=readme)

## Windows Binaries

Binaries for Windows 32 or Windows 64 bit (XP or higher) can be obtained from the project page [https://ingram-braun.net/public/programming/perl/wayback-url-robot-html/](https://ingram-braun.net/public/programming/perl/wayback-url-robot-html/#ib_campaign=$archive-pl-1.4&ib_medium=repository&ib_source=readme)

## To Do

* add more PDF metadata tags
