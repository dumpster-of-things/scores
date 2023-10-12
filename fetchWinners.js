const jsdom = require("jsdom");
const { JSDOM } = jsdom;

// * if ran during the current week,
//   but before that week has activated (no games yet),
//   nothing is returned,
//   and my slickass bash liner-oners go off the rails similar to a crazy train
// * instead, i'm trying to have it always show the most recent scoreboard.
//   accessing the prvious weeks' data is simple enough:
//   notice the url below,
//   it effectively represents a weekly := listOf:[ "tuple"Of:( team[0,1]{...} ), ] - aka `games`.
//
/* PREVIOUS SOREBOARDS
seasonType:
#            1:    pre-season
#            2: normal-season
#            3:   post-season
#            4:    off-season
#            5:      ?-season
#            6:      ?-season
*/ //         `-----------------------------------------------------------------------.
fetch("https://www.espn.com/college-football/scoreboard/_/week/6/year/2023/seasontype/2", {
  method: 'GET', //bash:            $1                        $3       $2            ${4:-2}
  headers: {
     "authority": 'www.espn.com',
     "accept-language": 'en-US,en;q=0.9',
     "cache-control": 'no-cache',
     "cookie": 'edition-view=espn-en-us; country=us; edition=espn-en-us; region=ccpa;',
     "dnt": '1',
     "pragma": 'no-cache',
     "referer": 'https://www.espn.com/college-football/scoreboard',
     "sec-fetch-dest": 'document',
     "sec-fetch-mode": 'navigate',
     "sec-fetch-site": 'same-origin',
     "sec-gpc": '1',
     "upgrade-insecure-requests": '1'
  }
})
.then(response => response.text())
.then(textString => {
  const dom = new JSDOM(`${textString}`);
  //#weDeeplyNested: `/html/body/div[1]/div/div/div/main/div[3]/div/div[1]/div[1]/div/section/div/section[1]/div[1]/div/div[1]/div/div/ul`:
  var games = dom.window.document.querySelectorAll('ul[class="ScoreboardScoreCell__Competitors"] > li[class$="winner"]');
  // these `<ul>` are the "tuple"s mentioned above;
  //...
  // In bash, it is trivial to access the obtusely nested json,
  //  and so this is where the team[0,1]{...} objects could be fully populated as follows:
  //  ` [ game( team[0]:{name,teamColor,altColor,score,(winner|loser),...}, team[1]:{...} ), ] `
  //...you'd already have everything you came for,
  //...you'd be home-free,
  //...but too poor for it to matter.
  // In js, these html scaffolding elements (`<ul>` are, for now, the best I've got.
  for (var i = 0; i < games.length; i++) {
    // this returns a list of the winners' href
    // this href is an also an attribute.json of that team{}'s.
    // thought as a backup plan i could probably access team data using their href,
    //beWrong.
    // when I parsed the html on the other end of one, it returned data for a different team, in another sport and state.
    //...noped.
    console.log(games[i].querySelector('a[href^="/college-football/team/_/id"]').href);
  }
  // * the json we want is somewhere near:
  //   ` html/body/table/tbody/tr[72]/td[2]/text() `
  //
  //const elem = dom.window.document.querySelector("body > table > tbody > tr:nth-child(72)");
  //const jsonData = JSON.parse(elem.text());
  //console.log(jsonData);
  //const jsonData = JSON.parse(dom.window.__CONFIG__.textContent);
})
.catch(error => {
  console.error('Error:', error);
});

/*// untested regex-based method, courtesy of poe(gpt):
fetch('https://example.com/data')
  .then(response => response.text())
  .then(html => {
    const jsonDataRegex = /var data = ({.*?});/;
    const match = html.match(jsonDataRegex);
    if (match) {
      const jsonData = JSON.parse(match[1]);
      console.log(jsonData);
    } else {
      console.error('JSON data not found in HTML response');
    }
  })
  .catch(error => {
    console.error('Error:', error);
  });
*/



/* bash:
### parseGames
while read team[1] ; do ((i==0)) && { team[0]="${team[1]}"; } || { games[${#games[@]}]="[${team[0]},${team[1]}]"; }; ((i=i!=1?1:0)); done < <(cat $* | sed 's/\/li>/\n/g;s/},{/}\n{/g' | grep '"score":' | sed 's/{\"/{\n\t\"/g;s/\"}/\"\n}/g' | awk '!a[$0]++' | op '??=\"id\"\:*isHome*' '%\,\"records*' '({).' '.(})' ); echo '{"games":['; printf '%s,' "${games[@]::${#games[@]}-1}"; echo "${games[-1]}]}"
*/

/* bash:
### pmpp
point=($(cat $* | grep -nEo '(<body>|</body>)' | cut -d\: -f1 )) && i=0 || exit 1
while read line ; do case "$line" in \<[!\/]*|\{*|\[*) printf "%$((i++))s $line\n" ;; \<\/*|*\]|*\}) printf "%$((i--))s $line\n" ;; *) printf "%$((i=i<0?0:i))s $line\n" ; esac ; done < <(sed -n "${point[0]},${point[1]}~1p" $* | sed 's/</\n</g;s/>/>\n/g;s/{/{\n/g;s/\[/\[\n/g;s/\]/\n\]/g;s/}/\n}/g;s/,/,\n/g' )
*/
