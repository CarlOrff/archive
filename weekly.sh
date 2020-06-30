#!/bin/sh
archive="https://web.archive.org/save/"
urllist=(
	http://archivalia.hypotheses.org/
	http://b.hatena.ne.jp/Archaeopath/rss
	http://www.chess-international.de/
	https://perlenvombodensee.wordpress.com/
	https://www.reddit.com/r/Archaeology/
	http://schach-hildesheim.de/
	http://www.schachbund.de/
	https://schach-hellern.de/
	'https://twitter.com/search?f=tweets%23vertical=default&q=%23chesshistory'
)
for url in "${urllist[@]}" 
do
    wget --header="Accept: text/html" -P "/private-backup/bashscr/wayback/downloads/" --user-agent="Mozilla/5.0 (Macintosh; Intel Mac OS X 10.8; rv:21.0) Gecko/20100101 Firefox/21.0" -qO- "$archive$url" >/dev/null 2>&1
    # schreibe STDOUT
	sleep 20
done