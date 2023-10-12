#!/usr/bin/env bash

Dipset() { cat <<EOF
NAME:
   ${0##*\/}
USAGE:
   \`${0##*\/} <SPORTS-LEAGUE>\`
DESCRIPTION:
   scrape espn for live scoreboard data for a given sport.
   generate html page with said data.
   begrudgingly learn javascript while doing stuff with team colors.

   <SPORTS-LEAGUE> must match whatever espn refers to it as in their url schema;
   for instance, this script was built working with "college-football" as \$1
      and so, presumably "mens-college-basketball" will work while that season is live.
   in any case, if this script stops working, then
    first check to see if the following url is valid with your desired <SPORTS-LEAGUE>
   ( https://www.espn.com/<SPORTS-LEAGUE>/scoreboard )

OPTIONAL PARAMETERS:
   -h,         Show this information.
    --help

EOF
	exit ${1:-0}
}
[[ "$1" != *(\-)@([hH])?([eE][lL][pP]) ]] || Dipset

## atleast while testing, offer a menu of known working sport-leagues when one is not specified at runtime.
#(($#!=0)) || Dipset 1
(($#!=0)) || { echo "select a sports-league..." && select sel in "cancel" "college-football" "mens-college-basketball" "womens-college-basketball" ; { [[ "$sel" != "cancel" ]] && { sport="$sel" ; break ; } || exit 0 ; } ; }

mkdir -p ${Od:=~/Projects/scoreboard/${sport:=${1//\ /\-}}}

# CURRENT (WEEKLY) SCOREBOARD
fetchScores() { curl -s "https://www.espn.com/$1/scoreboard" -H 'authority: www.espn.com' -H 'accept: text/html,application/xhtml+xml,application/xml;q=0.9,application/json' -H 'accept-language: en-US,en;q=0.9' -H 'cache-control: no-cache' -H 'cookie: edition-view=espn-en-us; country=us; edition=espn-en-us; region=ccpa;' -H 'dnt: 1' -H 'pragma: no-cache' -H 'referer: https://www.espn.com/college-football/scoreboard' -H 'sec-fetch-dest: document' -H 'sec-fetch-mode: navigate' -H 'sec-fetch-site: same-origin' -H 'sec-gpc: 1' -H 'upgrade-insecure-requests: 1' --compressed | tee $Od/$(date +'%Y%m%d%H%M').scoreboard.html ; }
# * For current week, the json is directly retrievable through espn's pseudo-hidden api:
fetchScoresJSON() { curl -s 'https://site.web.api.espn.com/apis/v2/scoreboard/header?sport=football&league=college-football&region=us&lang=en&contentorigin=espn&tz=America%2FNew_York' -H 'authority: site.web.api.espn.com' -H 'accept: application/json' -H 'accept-language: en-US,en;q=0.9' -H 'cache-control: no-cache' -H 'dnt: 1' -H 'origin: https://www.espn.com' -H 'pragma: no-cache' -H 'referer: https://www.espn.com/' -H 'sec-fetch-dest: empty' -H 'sec-fetch-mode: cors' -H 'sec-fetch-site: same-site' -H 'sec-gpc: 1' --compressed ; }

# HISTORICAL{ .../year/[2002-2023]/_/week/[1-16]/[1-6]  } SOREBOARDS
#seasonType:  ,------------------------------------'
#            1:    pre-season
#            2: normal-season
#            3:   post-season
#            4:    off-season
#            5:      ?-season
#            6:      ?-season
#fetchHistorical() { curl -s "https://www.espn.com/college-football/scoreboard/_/week/6/year/2023/seasontype/2" -H 'authority: www.espn.com' -H 'accept-language: en-US,en;q=0.9' -H 'cache-control: no-cache' -H 'cookie: edition-view=espn-en-us; country=us; edition=espn-en-us; region=ccpa;' -H 'dnt: 1' -H 'pragma: no-cache' -H 'referer: https://www.espn.com/college-football/scoreboard' -H 'sec-fetch-dest: document' -H 'sec-fetch-mode: navigate' -H 'sec-fetch-site: same-origin' -H 'sec-gpc: 1' -H 'upgrade-insecure-requests: 1' --compressed | tee college-football/2023-week6.scoreboard.html ; }
fetchHistorical() { local Od ; Of=${Od:=$1/$2/$3}/${4:-2}.scoreboard.html ; mkdir -p $Od ; curl -s "https://www.espn.com/$1/scoreboard/_/week/$3/year/$2/seasontype/${4:-2}" -H 'authority: www.espn.com' -H 'accept-language: en-US,en;q=0.9' -H 'cache-control: no-cache' -H 'cookie: edition-view=espn-en-us; country=us; edition=espn-en-us; region=ccpa;' -H 'dnt: 1' -H 'pragma: no-cache' -H 'referer: https://www.espn.com/$1/scoreboard' -H 'sec-fetch-dest: document' -H 'sec-fetch-mode: navigate' -H 'sec-fetch-site: same-origin' -H 'sec-gpc: 1' -H 'upgrade-insecure-requests: 1' --compressed -o "$Of" ; }
#WIP menuHistorical() { echo "what year?" ; read -p '[2002-2023|q]: ' sel[1] ; echo "what season type?" ; echo "(1 pre)(2 normal)(3 post)(4 off)(5 ?)(6 ?)()" ; read -p '[1-6|q]: ' sel[2] ; echo "what week of that season?" ; read -p '[1..16|q]: ' sel[3] ; for s in ${sel[@]}; do [[ "$s" != @([qQ])?([uU][iI][tT]) ]] || exit 0 ; done ; fetchHistorical ${sel[@]} ; }

getScores() { local Of ; [[ -f ${Of:=$Od/$(date +'%Y%m%d%H%M').scoreboard.html} ]] && cat "$Of" || fetchScores "$sport" ; }
updateIndicator() {
	### TODO: how to set button to 1/2 & 1/2 tied teams' (colors, score); and set/give each button an id=${GAME_EUID} - when clicked, selects game to track for colors, and whatever else...
	winners() { jq -Mc ".$FUNCNAME[]|[.abbrev,.teamColor,.altColor,.score]" -- $1 ; }
	ties() { jq -Mcj ".$FUNCNAME[][]|[.abbrev,.teamColor,.altColor,.score]"-- $1 ; }
	local Of n a b f s A B F S nope
	if [[ -f $1 ]]; then
		for winner in $(winners $1); do
			read a b f s < <(echo "${winner//[\[\,\]]/ }" )
			# css
			printf "%6s .winner$((++n)) { background-color: #${b//\"/}; color: #${f//\"/}; font-size: 33px; font-style: bold; }\n" >> ${1%\.*}.css
			# html
			printf "%4s <button class=\"winner$n\">${a//\"/}: ${s//\"/}</button>\n" >> ${1%\.*}.html
		done
		unset a b f s n
	else nope=1 ; fi
	if [[ -f $2 ]]; then
		for tie in $(ties $2); do
			read a b f s A B F S < <(echo "${tie//[\[\,\]]/ }" )
			# css
			printf "%6s .tied$((++n)) { background-color: #${b//\"/}; color: #${f//\"/}; font-size: 33px; font-style: bold; }\n" >> ${2%\.*}.css
			printf "%6s .tied$n { background-color: #${B//\"/}; color: #${F//\"/}; font-size: 33px; font-style: bold; }\n" >> ${2%\.*}.css
			# html
			printf "%4s <button class=\"tied$((--n))\">${a//\"/}: ${s//\"/}</button><button class=\"tied$n\">${A//\"/}: ${S//\"/}</button><br/>\n" >> ${2%\.*}.html
		done 
	else ((++nope)) ; fi
	((nope<2)) || exit $nope
	cat <<EOF
<!DOCTYPE html>
<html>
  <head>
    <style>
      body { background-color: #333; }
      h1 { color: #ABC; font-size: 42px; text-shadow: 0px 3px 6px rgba(0, 0, 0, 0.6), 0px -3px 6px rgba(0, 0, 0, 0.6), -3px 0px 6px rgba(0, 0, 0, 0.6), 3px 0px 6px rgba(0, 0, 0, 0.6); }
      footer { font-size: 14px; color: #454242; }
      .scoreboard { display: grid; grid-template-columns: auto auto auto auto; }
      button { text-shadow: 0px 1px 3px rgba(0, 0, 0, 0.5), 0px -1px 3px rgba(0, 0, 0, 0.5), -1px 0px 3px rgba(0, 0, 0, 0.5), 1px 0px 3px rgba(0, 0, 0, 0.5); }
EOF

        [[ ! -f ${1%\.*}.css ]] || cat ${1%\.*}.css
	[[ ! -f ${2%\.*}.css ]] || cat ${2%\.*}.css

	cat <<EOF
    </style>
  </head>
  <title>scoreboard</title>
  <body>
EOF

	[[ ! -f ${1%\.*}.html ]] || { echo '    <h1>WINNING</h1><br/>' ; echo '    <div class="scoreboard">' ; cat ${1%\.*}.html ; echo '    </div>' ; }
	[[ ! -f ${2%\.*}.html ]] || { echo '    <h1>TIED</h1><br/>' ; echo '    <div class="scoreboard">' ; cat ${2%\.*}.html ; echo '    </div>' ; }
	cat <<EOF
  </body>
  <footer>
    <br/>
    <br/>
    as of: `date +'%Y-%m-%d @ %H:%M:%S'`
  </footer>
</html>
EOF
}

i=0 ; unset games[*]
while read team[1] ; do (( i == 0 )) && team[0]="${team[1]}" || {
  games[${#games[@]}]="[ ${team[0]}, ${team[1]} ]"
 } ; ((i=i!=1?1:0))
done < <({ getScores "$sport" || exit 1 ; } | sed 's/\/li>/\n/g;s/},{/}\n{/g' | grep '"score":' | sed 's/{\"/{\n\t\"/g;s/\"}/\"\n}/g' | awk '!a[$0]++' | op '??=\"id\"\:*isHome*' '%\,\"records*' '({).' '.(})' )

unset Of
{ printf '{"games":[' ; printf '%s,' "${games[@]::${#games[@]}-1}" ; printf '"${games[-1]}"]}' ; } 2>/dev/null > ${Of:=$Od/$(date +'%Y%m%d').scores.json}

for ((i=0;i<$(jq -M '.games|length' -- $Of);i++)); do
 readarray scores < <(jq -M ".games[$i][0,1].score" -- $Of )
 (( winng = ${scores[0]} > ${scores[1]} ? 0 : ${scores[0]} == ${scores[1]} ? 2 : 1 ))
 (( winng == 2 )) && { jq -Mc ".games[$i]" -- $Of >> ${Of%\.*}.ties.json ; } || { jq -Mc ".games[$i][$winng]" -- $Of >> ${Of%\.*}.winners.json ; }
 unset winng scores[*]
done

now=$(date +'%Y%m%d%H%M')
[[ ! -f ${Of%\.*}.ties.json ]] || { { echo '{' ; echo ' "ties": [' ; { head -n-1 ${Of%\.*}.ties.json | op '(  ).' '.(,)' ; } ; { tail -n1 ${Of%\.*}.ties.json | op '(  ).' ; } ; echo ' ]' ; echo '}' ; } > ${Of%\/*}/$now.ties.json ; }
[[ ! -f ${Of%\.*}.winners.json ]] || { { echo '{' ; echo ' "winners": [' ; { head -n-1 ${Of%\.*}.winners.json | op '(  ).' '.(,)' ; } ; { tail -n1 ${Of%\.*}.winners.json | op '(  ).' ; } ; echo ' ]' ; echo '}' ; } > ${Of%\/*}/$now.winners.json ; }
[[ ! -f "$Od/index.html" ]] || mv "$Od/index.html" "$Od/.$(date +'%Y%m%d%H%M%S').index.html" ; updateIndicator "${Of%\/*}/$now.winners.json" "${Of%\/*}/$now.ties.json" > "$Od/index.html"
### TODO: add lil diddy about removing remnant cruft.
