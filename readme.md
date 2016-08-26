# archive.pl

*A script for archiving URL sets (HTML, PDF)*

Copyright (C) 2015- Ingram Braun (<https://ingram-braun.net/>)

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program. If not, see <http://www.gnu.org/licenses/>.

## Requirements

Perl 5.24 (earlier versions not tested but it is likely to work with every build that is capabale of getting the required modules installed)

## Usage

Collect URLs you want to archive in file `urls.txt` separated by one or more spaces (eg. `\n`, `\s`, `\r`) and call `perl archive.pl`. The script does to things: it fetches the URLs and extracts some metadata (works with HTML and PDF). It submits them to Internet Archive by opening them in a browser. This is necessary because Internet Archive blocks robots globally. Then it generates a HTML file with a link list that you may post to your blog. Alternatively you can get the link list as Atom feed. Regardless of the format you can upload the file on a server via FTP.

There are several optional switches

`-a` output as Atom feed instead of HTML

`-c <creator>` name of feed creator (feed only)

`-d <path>` FTP path

`-f <filename>` name of input file

`-n <username>` FTP user

`-o <host>` FTP host

`-p <password>` FTP password

`-u <URL>` feed URL (feed only)

## Project Page

<https://ingram-braun.net/public/programming/perl/wayback-url-robot-html/>

## Windows Binaries

Binaries for Windows 32 or Windows 64 bit (XP or higher) can be obtained from the project page <https://ingram-braun.net/public/programming/perl/wayback-url-robot-html/>

## To Do

* add more PDF metadata tags
