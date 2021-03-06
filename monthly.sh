#!/bin/sh
archive="https://web.archive.org/save/"
urllist=(
	https://www.altmetric.com/details/12360578
	https://www.altmetric.com/details/12360578/twitter
	https://www.altmetric.com/details/51497057
	https://www.altmetric.com/details/51497057/twitter
	https://www.altmetric.com/details/53198285
	https://www.altmetric.com/details/53198285/twitter
	https://www.archan-nhb.de/
	http://archilocheion.net/
	http://askoterion.linkarena.com/
	http://b.hatena.ne.jp/Archaeopath/bookmark
	https://www.caissa-kassel.de/
	http://www.chessmarginalia.com/
	http://www.chessrating.ru/players/24657816
	http://d-nb.info/gnd/1149773286
	https://docs.plesk.com/release-notes/obsidian/change-log/
	https://doi.org/10.5281/zenodo.803817
	https://doi.org/10.5281/zenodo.1239587
	https://doi.org/10.5281/zenodo.2527631
	https://ello.co/archaeopath
	https://de-de.facebook.com/FGUFGGOE/
	https://gitmemory.com/CarlOrff
	https://skgoslar.de/
	https://independent.academia.edu/IngramBraun
	https://mix.com/archaeopath
	http://www.msc1925.de/aktuelles.html
	http://www.der-neue-merker.at/aktuelles.php
	https://news.google.com/search?q=Schach&hl=de&gl=DE&ceid=DE%3Ade
	http://niedersaechsischer-schachverband.de/
	http://www.nordhessen.net/schachclub/
	http://nsv-online.de/
	https://www.orff.de/aktuelle-auffuehrungen/
	https://ratings.fide.com/profile/24657816
	https://www.reddit.com/user/Archaeopath
	https://www.reddit.com/user/Archaeopath?sort=top
	http://rolfengelhardt.de/html/scf.html
	http://www.schachbaunatal.de/index.html
	http://schachbezirk3.de/
	http://schachbezirk3.de/infos/main.php
	http://schachbezirk4.de/
	http://schachbezirk4.de/b4_home.php
	http://schachbezirk4.de/index_h.html
	http://schachbezirk4.de/index_l.html
	http://schachbezirk-oldenburg-ostfriesland.de/
	http://schachbezirk-osnabrueck-emsland.de/
	http://schach-bovenden.de/aktuelles/
	https://www.schachbund.de/gedenktafel.html
	http://www.schachclub-badsalzdetfurth.de/aktuelles
	http://schachfreunde-bad-emstal-wolfhagen.de/
	https://www.schachklub-bad-homburg.de/LigaOrakel/LigaOrakel.php?staffel=NSV_BEZ3_BL
	https://www.schachklub-bad-homburg.de/LigaOrakel/LigaOrakel.php?staffel=NSV_BEZ3_BK
	https://www.schachklub-bad-homburg.de/LigaOrakel/LigaOrakel.php?staffel=NSV_BEZ3_KL
	https://www.schachklub-bad-homburg.de/LigaOrakel/LigaOrakel.php?staffel=NSV_LLS
	https://www.schachklub-bad-homburg.de/LigaOrakel/LigaOrakel.php?staffel=NSV_VLO
	http://www.schachklub-hofgeismar.de/
	http://www.schach-korbach.de/
	http://www.schachverein-anderssen.de/
	http://tempo-goettingen.de/
	http://tempo-goettingen.de/inhalt.php?titel=Aktuelles\&datei=aktuelles.htm\&linie=1
	http://tempo-goettingen.de/navigation.php
	http://www.tg-wehlheiden.de/category/schach/
	'https://twitter.com/search?f=tweets&vertical=default&q=%23chessart'
	'https://twitter.com/search?f=tweets&vertical=default&q=%23chesshistory'
	'https://twitter.com/search?f=tweets&vertical=default&q=%23gameshistory'
	'https://twitter.com/search?f=tweets&vertical=default&q=Schach%20Kassel'
	'https://twitter.com/search?f=tweets&vertical=default&q=Schach%20G%C3%B6ttingen'
	https://www.vellmar.de/city_info/webaccessibility/index.cfm?item_id=856287&waid=419
	https://vk.com/id363726543
	http://werkstatt.toebelhuepfer.de/
	https://zenodo.org/record/321638
	https://zenodo.org/record/1239588
	https://zenodo.org/record/2843252
)
for url in "${urllist[@]}"
do
    wget --header="Accept: text/html" -P "/private-backup/bashscr/wayback/downloads/" --user-agent="Mozilla/5.0 (Macintosh; Intel Mac OS X 10.8; rv:21.0) Gecko/20100101 Firefox/21.0" -qO- "$archive$url" >/dev/null 2>&1
    # schreibe STDOUT
	sleep 20
done