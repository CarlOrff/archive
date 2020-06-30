#!/bin/sh
archive="https://web.archive.org/save/"
urllist=(
	https://www.heraeus-gold.de/de
	'https://scholar.google.com.sg/citations?user=6PEctPoAAAAJ&hl=en'
	https://www.mendeley.com/profiles/ingram-braun/
	https://www.mendeley.com/profiles/ingram-braun/publications/
	http://www.namenfinden.de/s/ingram+braun
	https://osf.io/yvwnt/analytics
	https://profiles.impactstory.org/u/0000-0002-7004-125X
	https://schmalenstroer.net/planet/feed/
	http://thekameraclub.co.uk/
	http://trendtwitter.com/Ingram_Braun/
	https://twita.top/user/Ingram_Braun
	https://twitter.com/AndreCosto
	https://twitter.com/_donalphonso
	https://twitter.com/kooptech
	https://twitter.com/MinusEins
	https://twitter.com/s_unter/lists/digital-humanities
	https://twitter.com/Seitenschach/lists/schach-twitteria
	'https://twitter.com/search?q=%22Ingram%20Braun%22'
	'https://twitter.com/search?f=tweets&vertical=default&q=%22Ingram%20Braun%22'
	http://wasserstand.edersee.de/
	'http://webmii.com/people?n=%22Ingram%20Braun%22'
	http://www.yasni.de/ingram+braun/person+information
)
for url in "${urllist[@]}"
do
    wget --header="Accept: text/html" -P "/private-backup/bashscr/wayback/downloads/" --user-agent="Mozilla/5.0 (Macintosh; Intel Mac OS X 10.8; rv:21.0) Gecko/20100101 Firefox/21.0" -qO- "$archive$url" >/dev/null 2>&1
    # schreibe STDOUT
	sleep 20
done