#!/bin/sh
archive="https://web.archive.org/save/"
urllist=(
	http://www.hamelnerschachverein.de/
	http://www.nsj-online.de/wordpress/
	https://www.reddit.com/r/Archaeology/
	https://www.reddit.com/r/Geschichte/
	https://www.schach-goettingen.de/cms/
	https://www.schachbezirk-braunschweig.de/
	http://www.schachbezirk-hannover.de/
	http://www.schachfreunde-hannover.de/
	http://www.schachbezirk1-nordhessen.de/
	http://schachbezirk1nordhessen.de/
	http://www.schachvereinigung-salzgitter.de/blog/
	http://skvellmar.de/
)
for url in "${urllist[@]}"
do
    wget --header="Accept: text/html" -P "/private-backup/bashscr/wayback/downloads/" --user-agent="Mozilla/5.0 (Macintosh; Intel Mac OS X 10.8; rv:21.0) Gecko/20100101 Firefox/21.0" -qO- "$archive$url" >/dev/null 2>&1
    # schreibe STDOUT
	sleep 20
done