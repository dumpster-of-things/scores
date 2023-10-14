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
(($#!=0)) || { echo "select a sports-league..." && select sel in "cancel" "college-football" "mens-college-basketball" "womens-college-basketball" ; { [[ "$sel" != "cancel" ]] || exit 0 ; break ; } ; }
mkdir -p ${Od:=~/Projects/scoreboard/${sel[0]:=${1//\ /\-}}}
for depends in 'op' 'wcl' 'iterdate' ; do [[ -x $(which $depends 2>/dev/null) ]] || { mkdir -p ${Od%\/*}/scripts ; curl -s "https://raw.githubusercontent.com/dumpster-of-things/scripts/main/$depends" -o ${Od%\/*}/scripts/$depends ; chmod 755 ${Od%\/*}/scripts/$depends ; alias $depends=${Od%\/*}/scripts/$depends ; } ; done
export PATH=${Od%\/*}/scripts:$PATH
fetchScores() { curl -s "https://www.espn.com/$1/scoreboard" -H 'authority: www.espn.com' -H 'accept: text/html,application/xhtml+xml,application/xml;q=0.9,application/json' -H 'accept-language: en-US,en;q=0.9' -H 'cache-control: no-cache' -H 'cookie: edition-view=espn-en-us; country=us; edition=espn-en-us; region=ccpa;' -H 'dnt: 1' -H 'pragma: no-cache' -H 'referer: https://www.espn.com/college-football/scoreboard' -H 'sec-fetch-dest: document' -H 'sec-fetch-mode: navigate' -H 'sec-fetch-site: same-origin' -H 'sec-gpc: 1' -H 'upgrade-insecure-requests: 1' --compressed | tee "$2" ; }
#fetchScoresJSON() { curl -s 'https://site.web.api.espn.com/apis/v2/scoreboard/header?sport=football&league=college-football&region=us&lang=en&contentorigin=espn&tz=America%2FNew_York' -H 'authority: site.web.api.espn.com' -H 'accept: application/json' -H 'accept-language: en-US,en;q=0.9' -H 'cache-control: no-cache' -H 'dnt: 1' -H 'origin: https://www.espn.com' -H 'pragma: no-cache' -H 'referer: https://www.espn.com/' -H 'sec-fetch-dest: empty' -H 'sec-fetch-mode: cors' -H 'sec-fetch-site: same-site' -H 'sec-gpc: 1' --compressed ; }
fetchHistorical() { local Of="$Od/$2/$3/${4:-2}.scoreboard.html" ; [[ -f "$Of" ]] && cat "$Of" || { mkdir -p ${Of%\/*} ; curl -s "https://www.espn.com/$1/scoreboard/_/week/$3/year/$2/seasontype/${4:-2}" -H 'authority: www.espn.com' -H 'accept-language: en-US,en;q=0.9' -H 'cache-control: no-cache' -H 'cookie: edition-view=espn-en-us; country=us; edition=espn-en-us; region=ccpa;' -H 'dnt: 1' -H 'pragma: no-cache' -H 'referer: https://www.espn.com/$1/scoreboard' -H 'sec-fetch-dest: document' -H 'sec-fetch-mode: navigate' -H 'sec-fetch-site: same-origin' -H 'sec-gpc: 1' -H 'upgrade-insecure-requests: 1' --compressed | tee "$Of" ; } ; }
menuHistorical() { read -p 'what year? [2002-2023|q]: ' sel[1] ; read -p "what week of that year's season? [1-16|q]: " sel[2] ; read -p "seasonType? 1(pre),2(normal),3(post),4(off),5(?),6(?),q(quit) [1-6|q]: " sel[3] ; for s in ${sel[@]}; do [[ "$s" != @([qQ])?([uU][iI][tT]) ]] || exit 0 ; done ; fetchHistorical ${sel[@]} ; }
getScores() { local Of="$Od/$(date +'%Y%m%d%H%M').scoreboard.html" ; [[ -f "$Of" ]] && cat "$Of" || fetchScores "${sel[0]}" "$Of" ; }
WhenIt() {
 local year week today seasonStart
 today=$(date +'%Y%m%d') ; year=$(date +'%Y') ; seasonStart=$(iterdate "${year}0823" "${year}0901" +sat | tail -n1)
 (( $today > $seasonStart )) && week=$(iterdate "$seasonStart" "$today" +sat | wcl) || { ((year-=1)) ; week=16 ; }
 echo "$year" "$((week>16?16:week))"
}
parseGames() {
 local game team
 i=0 ; while read team[1] ; do ((i==0)) && team[0]="${team[1]}" || { game[${#game[@]}]="[ ${team[0]}, ${team[1]} ]" ; } ; ((i=i!=1?1:0)) ; done < <(cat - | sed 's/\/li>/\n/g;s/},{/}\n{/g' | grep '"score":' | sed 's/{\"/{\n\t\"/g;s/\"}/\"\n}/g' | awk '!a[$0]++' | op '??=\"id\"\:*isHome*' '%\,\"records*' '({).' '.(})' )
 (( ${#game[@]} > 1 )) && { printf '{"games":[' && printf '%s,' "${game[@]::${#game[@]}-1}" && printf "${game[-1]} ]}" ; } || { (( ${#game[@]} != 1 )) || { printf "{ \"games\":[ $game ] }" ; } ; }
}
games=$(getScores "${sel[0]}" | parseGames)
[[ -n "$games" ]] || { Xc=2 ; games=$(fetchHistorical ${sel[0]} $(WhenIt) 2 | parseGames) ; }
[[ -n "$games" ]] || { Xc=3 ; games=$(menuHistorical | parseGames) ; }
[[ -n "$games" ]] || { echo "$Xc" ; exit 2 ; }
g=$(echo "$games" | jq '.games|length')
[[ $g == [1-9]*([0-9]) ]] || { echo "$Xc" ; exit 3 ; }
for ((i=0;i<g;i++)); do
 readarray scores < <(echo "$games" | jq -M ".games[$i][0,1].score" -- 2>/dev/null )
 (( ${#scores[@]} > 0 )) || { echo "$Xc" ; exit 4 ; }
 (( winner = ${scores[0]} > ${scores[1]} ? 0 : ${scores[0]} == ${scores[1]} ? 2 : 1 ))
 (( winner == 2 )) && TIED[${#TIED[@]}]=$(echo "games" | jq -Mc ".games[$i]") || WINNING[${#WINNING[@]}]=$(echo "$games" | jq -Mc ".games[$i][$winner]")
 unset winner scores[*]
done
(( ${#WINNING[@]} + ${#TIED[@]} > 0 )) || { echo "$Xc" ; exit 5 ; }
Winners() { jq -Mc ".$FUNCNAME[]|[.abbrev,.teamColor,.altColor,.score]" ; }
Ties() { jq -Mcj ".$FUNCNAME[][]|[.abbrev,.teamColor,.altColor,.score]" ; }
unset n a b f s A B F S
nope=0
if [[ -n $WINNING ]]; then
 WINNING=$({ printf '{"Winners":[' && printf '%s,' "${WINNING[@]::${#WINNING[@]}-1}" ; printf "${WINNING[-1]} ]}" ; })
 n=0
 for winner in $(echo "$WINNING" | Winners); do
  read a b f s < <(echo "${winner//[\[\,\]]/ }" )
  ((n+=1))
  CSS[${#CSS[@]}]=$(printf "%4s .winner$n { background-color: #${b//\"/}; color: #${f//\"/}; font-size: 33px; font-style: bold; }\n")
  WinnerHTML[${#WinnerHTML[@]}]=$(printf "%6s <button class=\"winner$n\">${a//\"/}: ${s//\"/}</button>\n")
 done
 unset a b f s n
else nope=1 ; fi
if [[ -n $TIED ]]; then
 TIED=$({ printf '{"Ties":[' && printf '%s,' "${TIED[@]::${#TIED[@]}-1}" && printf "${TIED[-1]} ]}" ; })
 n=0
 for tie in $(echo "$TIED" | Ties); do
  read a b f s A B F S < <(echo "${tie//[\[\,\]]/ }" )
  ((n+=1))
  CSS[${#CSS[@]}]=$(printf "%4s .tied$n { background-color: #${b//\"/}; color: #${f//\"/}; font-size: 33px; font-style: bold; }")
  CSS[${#CSS[@]}]=$(printf "%4s .tied$((n+1)) { background-color: #${B//\"/}; color: #${F//\"/}; font-size: 33px; font-style: bold; }")
  TiedHTML[${#TiedHTML[@]}]=$(printf "%6s <button class=\"tied$n\">${a//\"/}: ${s//\"/}</button><button class=\"tied$((n+1))\">${A//\"/}: ${S//\"/}</button><br/>")
 done
else ((++nope)) ; fi
((nope<2)) || { echo "$Xc" ; exit $((5+nope)) ; }

## backup pre-existing index.html before generating the new one
[[ ! -f "$Od/index.html" ]] || mv "$Od/index.html" "$Od/.$(date +'%Y%m%d%H%M%S').index.html" 

{ cat <<EOF
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

printf '%s\n' "${CSS[@]}"

cat <<EOF
    </style>
  </head>
  <title>scoreboard</title>
  <body>
EOF

[[ -z $WinnerHTML ]] || { printf '%4s <h1>WINNING</h1><br/>\n%4s <div class="scoreboard">\n' ; printf "%s\n" "${WinnerHTML[@]}" ; printf '%4s </div>\n' ; }
[[ -z $TiedHTML ]] || { printf '%4s <h1>TIED</h1><br/>\n%4s <div class="scoreboard">\n' ; printf "%s\n" "${TiedHTML[@]}" ; printf '%4s </div>\n' ; }

cat <<EOF
  </body>
  <footer>
    <br/>
    <br/>
    as of: `date +'%Y-%m-%d @ %H:%M:%S'`
  </footer>
</html>
EOF
} | tee "$Od/index.html"
